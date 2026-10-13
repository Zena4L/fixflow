require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @requester = create_requester!
    @agent = create_staff!
    @request = create_request!(requester: @requester, status: :open, staff: @agent)
  end

  test "has exactly one author" do
    assert_not Comment.new(service_request: @request, body: "x").valid?
    assert_not Comment.new(service_request: @request, body: "x", user: @requester, staff_member: @agent).valid?
    assert Comment.new(service_request: @request, body: "x", user: @requester).valid?
  end

  test "internal notes are staff-only" do
    comment = Comment.new(service_request: @request, body: "x", user: @requester, internal: true)

    assert_not comment.valid?
    assert_includes comment.errors[:internal], "notes can only be written by staff"
  end

  test "closed requests do not accept comments" do
    closed = create_request!(requester: @requester, status: :closed, staff: @agent)
    comment = Comment.new(service_request: closed, body: "x", user: @requester)

    assert_not comment.valid?
  end

  test "posted comments are immutable" do
    comment = @request.comments.create!(user: @requester, body: "First")

    assert_raises(ActiveRecord::ReadOnlyRecord) { comment.update!(body: "Edited") }
  end

  test "commenting is recorded in the activity log, flagged when internal" do
    @request.comments.create!(staff_member: @agent, body: "Note", internal: true)

    activity = @request.activities.reload.last
    assert_equal "commented", activity.kind
    assert_equal @agent, activity.actor
    assert_predicate activity, :internal?
    assert_equal "Added an internal note", activity.summary
  end

  test "the database enforces the single-author and staff-only-internal rules" do
    now = Time.current
    base = {service_request_id: @request.id, body: "x", created_at: now, updated_at: now}

    assert_raises(ActiveRecord::CheckViolation) { Comment.insert_all!([base]) }
    assert_raises(ActiveRecord::CheckViolation) do
      Comment.insert_all!([base.merge(user_id: @requester.id, internal: true)])
    end
  end
end
