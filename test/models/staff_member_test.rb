require "test_helper"

class StaffMemberTest < ActiveSupport::TestCase
  test "email is stored lowercase and trimmed, matching Rodauth's case-insensitive login" do
    staff = create_staff!(email: "  Pat.Admin@Example.TEST ")

    assert_equal "pat.admin@example.test", staff.reload.email
    assert_equal staff, StaffMember.find_by(email: "PAT.ADMIN@example.test")
  end

  test "email must be unique among open accounts, ignoring case" do
    existing = create_staff!(email: "taken@example.test")

    duplicate = StaffMember.new(email: "TAKEN@example.test", name: "Dup", role: :agent)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"

    existing.update!(status: :closed)
    assert duplicate.valid?, "a closed account's email can be reused"
  end

  test "email must look like an email address" do
    staff = StaffMember.new(email: "not-an-email", name: "Bad", role: :agent)

    assert_not staff.valid?
    assert_includes staff.errors[:email], "is invalid"
  end
end
