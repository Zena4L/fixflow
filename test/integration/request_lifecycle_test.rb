require "test_helper"

# The core FixFlow journey, driven entirely through HTTP as real users would.
class RequestLifecycleTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::AuthHelpers

  setup do
    @requester = create_requester!(name: "Riley")
    @agent = create_staff!(role: :agent, name: "Alex")
  end

  test "submit → triage → assign → start → resolve → close → reopen" do
    # Requester submits.
    login_as(@requester, portal: :requester)
    assert_difference -> { ServiceRequest.count }, 1 do
      post "/requester/service_requests", params: {service_request: {
        title: "VPN drops every hour", description: "Disconnects on the hour, every hour.", priority: "high"
      }}
    end
    request = ServiceRequest.last
    assert_equal @requester, request.requester
    assert_predicate request, :submitted?

    # Requester adds detail as a comment.
    post "/requester/service_requests/#{request.id}/nested_comments", params: {comment: {body: "Happens on Wi-Fi only."}}
    assert_equal [@requester], request.comments.reload.map(&:author)

    # Staff work the request.
    reset! # fresh session: next user signs in from scratch
    login_as(@agent, portal: :staff)
    commit_action(request, :triage, priority: "urgent")
    assert_predicate request.reload, :open?
    assert_predicate request, :urgent?

    commit_action(request, :assign, assignee_id: @agent.id)
    assert_equal @agent, request.reload.assignee

    commit_action(request, :start)
    assert_predicate request.reload, :in_progress?

    post "/staff/service_requests/#{request.id}/nested_comments",
      params: {comment: {body: "Checking the VPN concentrator logs.", internal: "1"}}
    assert request.comments.reload.last.internal?

    commit_action(request, :resolve, resolution_note: "Raised the DHCP lease time.")
    assert_predicate request.reload, :resolved?
    assert_equal "Raised the DHCP lease time.", request.resolution_note

    # Requester confirms, then finds the fix did not hold and reopens.
    reset! # fresh session: next user signs in from scratch
    login_as(@requester, portal: :requester)
    get "/requester/service_requests/#{request.id}"
    assert_response :ok
    assert_includes response.body, "Raised the DHCP lease time."

    commit_action(request, :close, portal: :requester)
    assert_predicate request.reload, :closed?

    # Closed is final for requesters...
    commit_action(request, :reopen, portal: :requester, reason: "Still dropping.", expect: :forbidden)
    assert_predicate request.reload, :closed?

    # ...but staff can reopen it.
    reset! # fresh session: next user signs in from scratch
    login_as(@agent, portal: :staff)
    commit_action(request, :reopen, reason: "Requester reports it recurred.")
    assert_predicate request.reload, :open?
    assert_equal "Reopened: Requester reports it recurred.", request.comments.reload.last.body

    expected = %w[created commented status_changed updated assigned status_changed commented
      status_changed status_changed status_changed commented]
    assert_equal expected, request.activities.reload.map(&:kind)
  end

  test "a requester can reopen a resolved request with a reason" do
    request = create_request!(requester: @requester, status: :resolved, staff: @agent)
    login_as(@requester, portal: :requester)

    commit_action(request, :reopen, portal: :requester, reason: "", expect: :invalid)
    assert_predicate request.reload, :resolved?

    commit_action(request, :reopen, portal: :requester, reason: "The fix did not work.")
    assert_predicate request.reload, :open?
  end

  private

  def commit_action(request, action, portal: :staff, expect: :see_other, **inputs)
    post "/#{portal}/service_requests/#{request.id}/record_actions/#{action}", params: {interaction: inputs}
    case expect
    when :see_other then assert_response(:see_other, "#{action} should succeed: #{response.status}")
    when :invalid then assert_response(:unprocessable_content)
    when :forbidden then assert_includes [403, 404], response.status, "#{action} should be refused"
    end
  end
end
