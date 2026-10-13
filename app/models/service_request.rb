# == Schema Information
#
# Table name: service_requests
#
#  id              :integer          not null, primary key
#  closed_at       :datetime
#  description     :text             not null
#  priority        :integer          default("medium"), not null
#  resolution_note :text
#  resolved_at     :datetime
#  status          :integer          default("submitted"), not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  assignee_id     :integer
#  requester_id    :integer          not null
#
# Indexes
#
#  index_service_requests_on_assignee_id   (assignee_id)
#  index_service_requests_on_created_at    (created_at)
#  index_service_requests_on_priority      (priority)
#  index_service_requests_on_requester_id  (requester_id)
#  index_service_requests_on_status        (status)
#
# Foreign Keys
#
#  assignee_id   (assignee_id => staff_members.id)
#  requester_id  (requester_id => users.id)
#
class ServiceRequest < ::ResourceRecord
  include ActivityTracking

  # add concerns above.

  # The workflow. Any status change not listed here is rejected by validation,
  # whoever attempts it; *who* may trigger each move lives in the policies.
  TRANSITIONS = {
    "submitted" => %w[open],
    "open" => %w[in_progress],
    "in_progress" => %w[resolved],
    "resolved" => %w[closed open],
    "closed" => %w[open]
  }.freeze
  REOPENABLE_STATUSES = %w[resolved closed].freeze
  TRACKED_FIELDS = %w[title description priority].freeze
  REFERENCE_PREFIX = "FF-"
  # add constants above.

  enum :priority, {low: 0, medium: 1, high: 2, urgent: 3}, validate: true
  enum :status, {submitted: 0, open: 1, in_progress: 2, resolved: 3, closed: 4}, validate: true
  # add enums above.

  # add model configurations above.

  belongs_to :requester, class_name: "User", inverse_of: :service_requests
  belongs_to :assignee, optional: true, class_name: "StaffMember", inverse_of: :assigned_requests
  # add belongs_to associations above.

  # add has_one associations above.

  has_many :comments, dependent: :delete_all
  has_many :activities, -> { order(:created_at, :id) }, dependent: :delete_all
  # add has_many associations above.

  # add attachments above.

  scope :active, -> { where(status: %i[submitted open in_progress]) }
  scope :unassigned, -> { where(assignee_id: nil) }
  # add scopes above.

  validates :title, presence: true, length: {maximum: 200}
  validates :description, presence: true, length: {maximum: 10_000}
  validates :resolution_note, length: {maximum: 5_000}
  validates :resolution_note, presence: true, if: -> { resolved? && will_save_change_to_status? }
  validates :assignee, presence: {message: "must be set before work starts"}, if: :in_progress?
  validate :starts_as_submitted, on: :create
  validate :status_change_follows_workflow, on: :update
  validate :closed_request_is_read_only, on: :update
  validate :assignee_is_active, if: -> { assignee.present? && will_save_change_to_assignee_id? }
  # add validations above.

  after_create :record_created_activity
  after_update :record_update_activities
  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # Human-facing identifier, derived from the primary key so it can never drift.
  def reference
    "#{REFERENCE_PREFIX}#{id.to_s.rjust(5, "0")}" if id
  end

  def to_label
    [reference, title].compact.join(" · ")
  end

  def can_transition_to?(target)
    TRANSITIONS.fetch(status, []).include?(target.to_s)
  end

  def reopenable?
    REOPENABLE_STATUSES.include?(status)
  end

  # The single entry point for workflow moves. Locks the row so two people
  # acting on the same request at once cannot both apply a transition.
  # `changes` lets a move carry edits that must land atomically with it
  # (e.g. adjusting priority while triaging).
  def transition_to!(target, actor:, note: nil, changes: {})
    target = target.to_s
    with_lock do
      unless can_transition_to?(target)
        errors.add(:status, "cannot change from #{human_status} to #{self.class.human_status(target)}")
        raise ActiveRecord::RecordInvalid, self
      end

      self.actor = actor
      assign_attributes(changes)
      self.status = target
      apply_transition_side_effects(target, actor:, note:)
      save!
    end
    self
  rescue ActiveRecord::RecordInvalid
    discard_unsaved_changes
    raise
  end

  def assign_to!(staff_member, actor:)
    with_lock do
      self.actor = actor
      self.assignee = staff_member
      save!
    end
    self
  rescue ActiveRecord::RecordInvalid
    discard_unsaved_changes
    raise
  end

  def human_status = self.class.human_status(status)

  def self.human_status(value) = value.to_s.humanize

  # add methods above. add private methods below.

  private

  # A rejected move must not leave half-applied attributes behind (they would
  # also block the next with_lock). Errors are kept for display.
  def discard_unsaved_changes
    kept_errors = errors.dup
    restore_attributes
    errors.copy!(kept_errors)
  end

  def apply_transition_side_effects(target, actor:, note:)
    case target
    when "in_progress"
      self.assignee ||= actor if actor.is_a?(StaffMember)
    when "resolved"
      self.resolution_note = note
      self.resolved_at = Time.current
    when "closed"
      self.closed_at = Time.current
    when "open"
      # Reopening clears the previous outcome.
      self.resolved_at = nil
      self.closed_at = nil
    end
  end

  def starts_as_submitted
    errors.add(:status, "must start as submitted") unless submitted?
  end

  def status_change_follows_workflow
    return unless will_save_change_to_status?

    from, to = status_change_to_be_saved
    return if TRANSITIONS.fetch(from.to_s, []).include?(to.to_s)

    errors.add(:status, "cannot change from #{self.class.human_status(from)} to #{self.class.human_status(to)}")
  end

  def closed_request_is_read_only
    return unless status_in_database == "closed"
    return if will_save_change_to_status? # reopening is the only way out

    errors.add(:base, "Closed requests are read-only. Reopen the request to change it.") if has_changes_to_save?
  end

  def assignee_is_active
    errors.add(:assignee, "must be an active staff member") unless assignee.active?
  end

  def record_created_activity
    record_activity!(self, "created", changeset: {"priority" => priority})
  end

  def record_update_activities
    if saved_change_to_status?
      from, to = saved_change_to_status
      record_activity!(self, "status_changed", from_status: from, to_status: to,
        changeset: (to == "resolved") ? {"resolution_note" => resolution_note} : nil)
    end

    if saved_change_to_assignee_id?
      from_id, to_id = saved_change_to_assignee_id
      record_activity!(self, to_id ? "assigned" : "unassigned",
        changeset: {"assignee" => [StaffMember.find_by(id: from_id)&.to_label, assignee&.to_label]})
    end

    changed_fields = saved_changes.slice(*TRACKED_FIELDS)
    return if changed_fields.empty?

    # Long text is summarised rather than copied into the audit log.
    changed_fields["description"] = ["(previous)", "(updated)"] if changed_fields.key?("description")
    record_activity!(self, "updated", changeset: changed_fields)
  end
end
