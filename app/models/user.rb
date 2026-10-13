# == Schema Information
#
# Table name: users
#
#  id            :integer          not null, primary key
#  email         :string           not null
#  name          :string
#  password_hash :string
#  status        :integer          default("unverified"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE WHERE status IN (1, 2)
#
class User < ResourceRecord
  include Rodauth::Rails.model(:user)

  # add concerns above.

  # add constants above.

  enum :status, unverified: 1, verified: 2, closed: 3
  # add enums above.

  # add model configurations above.

  # add belongs_to associations above.

  # add has_one associations above.

  has_many :service_requests, foreign_key: :requester_id, inverse_of: :requester, dependent: :restrict_with_error
  # add has_many associations above.

  # add attachments above.

  # add scopes above.

  validates :email, presence: true
  validates :name, length: {maximum: 100}
  # add validations above.

  # add callbacks above.

  # add delegations above.

  # add misc attribute macros above.

  def to_label
    name.presence || email
  end

  # add methods above. add private methods below.
end
