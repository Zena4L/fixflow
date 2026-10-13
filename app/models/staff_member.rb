# == Schema Information
#
# Table name: staff_members
#
#  id            :integer          not null, primary key
#  active        :boolean          default(TRUE), not null
#  email         :string           not null
#  name          :string           default(""), not null
#  password_hash :string
#  role          :integer          default("agent"), not null
#  status        :integer          default("verified"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_staff_members_on_email  (email) UNIQUE WHERE status IN (1, 2)
#
class StaffMember < ResourceRecord
  include Rodauth::Rails.model(:staff_member)

  # add concerns above.

  # add constants above.

  # Staff accounts are provisioned by an admin (no self-signup or email
  # verification), so they start out verified.
  enum :status, {unverified: 1, verified: 2, closed: 3}, default: :verified
  # Index 0 is the most privileged role (Plutonium convention).
  enum :role, {admin: 0, agent: 1}, validate: true
  # add enums above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  has_many :assigned_requests, class_name: "ServiceRequest", foreign_key: :assignee_id,
    inverse_of: :assignee, dependent: :restrict_with_error
  # add has_many associations above.

  # add attachments above.

  scope :active, -> { where(active: true) }
  # add scopes above.

  validates :email, presence: true
  validates :name, presence: true, length: {maximum: 100}
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  def to_label
    name.presence || email
  end

  # add methods above. add private methods below.
end
