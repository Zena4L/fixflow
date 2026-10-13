require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "the log is append-only" do
    activity = create_request!.activities.first

    assert_raises(ActiveRecord::ReadOnlyRecord) { activity.update!(kind: "updated") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { activity.destroy! }
  end

  test "maps actors onto the right column" do
    requester = create_requester!
    staff = create_staff!

    assert_equal({user: requester, staff_member: nil}, Activity.actor_attributes(requester))
    assert_equal({user: nil, staff_member: staff}, Activity.actor_attributes(staff))
    assert_equal({user: nil, staff_member: nil}, Activity.actor_attributes(nil))
    assert_raises(ArgumentError) { Activity.actor_attributes(Object.new) }
  end

  test "events without an actor are attributed to the system" do
    request = create_request!
    activity = request.activities.create!(kind: "updated", changeset: {"title" => %w[a b]})

    assert_equal "System", activity.actor_name
  end

  test "rejects unknown kinds" do
    assert_not Activity.new(service_request: create_request!, kind: "hacked").valid?
  end
end
