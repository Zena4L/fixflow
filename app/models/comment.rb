# == Schema Information
#
# Table name: comments
#
#  id                 :integer          not null, primary key
#  body               :text             not null
#  internal           :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  service_request_id :integer          not null
#  staff_member_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_comments_on_service_request_id  (service_request_id)
#  index_comments_on_staff_member_id     (staff_member_id)
#  index_comments_on_user_id             (user_id)
#
# Foreign Keys
#
#  service_request_id  (service_request_id => service_requests.id) ON DELETE => cascade
#  staff_member_id     (staff_member_id => staff_members.id)
#  user_id             (user_id => users.id)
#
class Comment < ::ResourceRecord
  include ActivityTracking

  # add concerns above.

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

  validates :body, presence: true, length: {maximum: 5_000}
  validate :has_exactly_one_author
  validate :internal_notes_are_staff_only
  validate :request_accepts_comments, on: :create
  # add validations above.

  after_create :record_commented_activity
  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  # Comments are an immutable conversation record once posted.
  def readonly? = persisted? || super

  def author = staff_member || user

  def author_name = author&.to_label

  def to_label = "Comment by #{author_name || "unknown"}"

  # add methods above. add private methods below.

  private

  def has_exactly_one_author
    errors.add(:base, "A comment must have exactly one author") unless user.present? ^ staff_member.present?
  end

  def internal_notes_are_staff_only
    errors.add(:internal, "notes can only be written by staff") if internal? && staff_member.blank?
  end

  def request_accepts_comments
    errors.add(:base, "Closed requests cannot receive new comments") if service_request&.closed?
  end

  def record_commented_activity
    self.actor = author
    record_activity!(service_request, "commented", internal: internal?)
  end
end
