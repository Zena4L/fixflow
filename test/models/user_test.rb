require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is stored lowercase and trimmed, matching Rodauth's case-insensitive login" do
    user = create_requester!(email: " Riley@Example.TEST")

    assert_equal "riley@example.test", user.reload.email
  end

  test "email must be unique among open accounts, ignoring case" do
    create_requester!(email: "taken@example.test")

    duplicate = User.new(email: "Taken@example.test", status: :verified)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
