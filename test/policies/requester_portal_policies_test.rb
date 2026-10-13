require "test_helper"

class RequesterPortalPoliciesTest < ActiveSupport::TestCase
  setup do
    @owner = create_requester!
    @stranger = create_requester!
    @agent = create_staff!
  end

  def request_policy(record, user) = RequesterPortal::ServiceRequestPolicy.new(record, user:, entity_scope: nil)

  def comment_policy(record, user, parent: nil)
    RequesterPortal::CommentPolicy.new(record, user:, entity_scope: nil, parent:, parent_association: parent && :comments)
  end

  # Expected owner permissions per status. Strangers get nothing per record.
  OWNER_MATRIX = {
    submitted: %i[show update destroy],
    open: %i[show],
    in_progress: %i[show],
    resolved: %i[show close reopen],
    closed: %i[show]
  }.freeze
  ACTIONS = %i[show update destroy close reopen].freeze

  test "owner permissions follow the request status" do
    OWNER_MATRIX.each do |status, allowed|
      request = create_request!(requester: @owner, status:, staff: @agent)
      ACTIONS.each do |action|
        assert_equal allowed.include?(action), request_policy(request, @owner).apply(:"#{action}?"),
          "owner #{action}? on #{status}"
        assert_not request_policy(request, @stranger).apply(:"#{action}?"), "stranger #{action}? on #{status}"
      end
    end
  end

  test "any requester may create; status, requester and assignee are never permitted" do
    policy = request_policy(ServiceRequest, @owner)

    assert policy.apply(:create?)
    assert_equal %i[title description priority], policy.permitted_attributes_for_create
  end

  test "relation_scope only returns the requester's own requests" do
    mine = create_request!(requester: @owner)
    create_request!(requester: @stranger)

    scope = request_policy(ServiceRequest, @owner).apply_scope(ServiceRequest.all, type: :active_record_relation)
    assert_equal [mine], scope.to_a
  end

  test "comments: public ones on own requests only, never internal notes" do
    mine = create_request!(requester: @owner, status: :open, staff: @agent)
    public_reply = mine.comments.create!(staff_member: @agent, body: "Public")
    mine.comments.create!(staff_member: @agent, body: "Internal", internal: true)
    create_request!(requester: @stranger, status: :open, staff: @agent).comments.create!(staff_member: @agent, body: "Other")

    scope = comment_policy(Comment, @owner).apply_scope(Comment.all, type: :active_record_relation)
    assert_equal [public_reply], scope.to_a
  end

  test "comments can be added to own, non-closed requests and never edited" do
    open_request = create_request!(requester: @owner, status: :open, staff: @agent)
    closed_request = create_request!(requester: @owner, status: :closed, staff: @agent)
    comment = open_request.comments.create!(user: @owner, body: "Mine")

    assert comment_policy(Comment, @owner, parent: open_request).apply(:create?)
    assert_not comment_policy(Comment, @stranger, parent: open_request).apply(:create?)
    assert_not comment_policy(Comment, @owner, parent: closed_request).apply(:create?)
    assert_not comment_policy(Comment, @owner).apply(:create?), "top-level (unparented) creation"
    assert_not comment_policy(comment, @owner).apply(:update?)
    assert_not comment_policy(comment, @owner).apply(:destroy?)
  end

  test "activity log is read-only and hides internal events" do
    request = create_request!(requester: @owner, status: :open, staff: @agent)
    request.comments.create!(staff_member: @agent, body: "Internal", internal: true)
    policy = RequesterPortal::ActivityPolicy.new(Activity, user: @owner, entity_scope: nil)

    assert_not policy.apply(:create?)
    visible = policy.apply_scope(Activity.all, type: :active_record_relation)
    assert_equal %w[created status_changed], visible.map(&:kind)
  end
end
