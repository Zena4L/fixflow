require "test_helper"

class StaffPortalPoliciesTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff!(role: :admin)
    @agent = create_staff!(role: :agent)
    @requester = create_requester!
  end

  def request_policy(record, user) = StaffPortal::ServiceRequestPolicy.new(record, user:, entity_scope: nil)

  WORKFLOW_ACTIONS = %i[triage start resolve close reopen].freeze

  # The policy's workflow buttons must agree with the model's state machine.
  EXPECTED_WORKFLOW = {
    submitted: %i[triage],
    open: %i[start],
    in_progress: %i[resolve],
    resolved: %i[close reopen],
    closed: %i[reopen]
  }.freeze

  test "workflow actions mirror ServiceRequest::TRANSITIONS for every status and role" do
    EXPECTED_WORKFLOW.each do |status, allowed|
      request = create_request!(requester: @requester, status:, staff: @agent)
      [@admin, @agent].each do |staff|
        WORKFLOW_ACTIONS.each do |action|
          assert_equal allowed.include?(action), request_policy(request, staff).apply(:"#{action}?"),
            "#{staff.role} #{action}? on #{status}"
        end
      end
    end
  end

  test "staff can edit and assign anything except closed requests" do
    open_request = create_request!(requester: @requester, status: :open, staff: @agent)
    closed_request = create_request!(requester: @requester, status: :closed, staff: @agent)

    assert request_policy(open_request, @agent).apply(:update?)
    assert request_policy(open_request, @agent).apply(:assign?)
    assert_not request_policy(closed_request, @agent).apply(:update?)
    assert_not request_policy(closed_request, @agent).apply(:assign?)
  end

  test "only admins delete; nobody on staff creates requests" do
    request = create_request!(requester: @requester)

    assert request_policy(request, @admin).apply(:destroy?)
    assert_not request_policy(request, @agent).apply(:destroy?)
    assert_not request_policy(ServiceRequest, @admin).apply(:create?)
  end

  test "status is never an editable attribute" do
    assert_not_includes request_policy(ServiceRequest, @admin).permitted_attributes_for_update, :status
  end

  test "only admins manage staff, and cannot demote or deactivate themselves" do
    admin_policy = StaffPortal::StaffMemberPolicy.new(@agent, user: @admin, entity_scope: nil)
    self_policy = StaffPortal::StaffMemberPolicy.new(@admin, user: @admin, entity_scope: nil)
    agent_policy = StaffPortal::StaffMemberPolicy.new(@admin, user: @agent, entity_scope: nil)

    assert admin_policy.apply(:update?)
    assert_includes admin_policy.permitted_attributes_for_update, :role
    assert_equal %i[name email], self_policy.permitted_attributes_for_update
    assert_not agent_policy.apply(:update?)
    assert_not StaffPortal::StaffMemberPolicy.new(StaffMember, user: @agent, entity_scope: nil).apply(:create?)
    assert_not admin_policy.apply(:destroy?), "staff are deactivated, never deleted"
  end

  test "requester accounts are read-only to staff" do
    policy = StaffPortal::UserPolicy.new(@requester, user: @admin, entity_scope: nil)

    assert policy.apply(:show?)
    assert_not policy.apply(:update?)
    assert_not policy.apply(:destroy?)
  end

  test "the activity log is read-only for staff" do
    activity = create_request!(requester: @requester).activities.first
    policy = StaffPortal::ActivityPolicy.new(activity, user: @admin, entity_scope: nil)

    assert policy.apply(:show?)
    assert_not policy.apply(:update?)
    assert_not policy.apply(:destroy?)
  end
end
