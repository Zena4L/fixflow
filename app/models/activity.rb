# == Schema Information
#
# Table name: activities
#
#  id                 :integer          not null, primary key
#  changeset          :json
#  from_status        :string
#  internal           :boolean          default(FALSE), not null
#  kind               :string           not null
#  to_status          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  service_request_id :integer          not null
#  staff_member_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_activities_on_service_request_id                 (service_request_id)
#  index_activities_on_service_request_id_and_created_at  (service_request_id,created_at)
#  index_activities_on_staff_member_id                    (staff_member_id)
#  index_activities_on_user_id                            (user_id)
#
# Foreign Keys
#
#  service_request_id  (service_request_id => service_requests.id) ON DELETE => cascade
#  staff_member_id     (staff_member_id => staff_members.id)
#  user_id             (user_id => users.id)
#
class Activity < ::ResourceRecord
  # add concerns above.

  KINDS = %w[created updated status_changed assigned unassigned commented].freeze
  # add constants above.

  # add enums above.

  # add model configurations above.

  belongs_to :service_request
  belongs_to :user, optional: true
  belongs_to :staff_member, optional: true
  # add belongs_to associations above.

  # add has_one associations above.

  # add has_many associations above.

  # add attachments above.

  scope :visible_to_requesters, -> { where(internal: false) }
  # add scopes above.

  validates :kind, inclusion: {in: KINDS}
  validate :at_most_one_actor
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # Maps an acting account onto the two nullable actor columns.
  def self.actor_attributes(actor)
    case actor
    when User then {user: actor, staff_member: nil}
    when StaffMember then {user: nil, staff_member: actor}
    when nil then {user: nil, staff_member: nil}
    else raise ArgumentError, "Unsupported actor: #{actor.class}"
    end
  end

  # The audit log is append-only.
  def readonly? = persisted? || super

  def actor = staff_member || user

  def actor_name = actor&.to_label || "System"

  def summary
    case kind
    when "created" then "Submitted the request"
    when "status_changed"
      "Moved from #{ServiceRequest.human_status(from_status)} to #{ServiceRequest.human_status(to_status)}"
    when "assigned" then "Assigned to #{Array(changeset&.dig("assignee")).last}"
    when "unassigned" then "Removed the assignee"
    when "updated" then "Updated #{changeset.to_h.keys.map(&:humanize).to_sentence.downcase}"
    when "commented" then internal? ? "Added an internal note" : "Commented"
    end
  end

  def to_label = summary.to_s

  # add methods above. add private methods below.

  private

  def at_most_one_actor
    errors.add(:base, "An activity has at most one actor") if user.present? && staff_member.present?
  end
end
