require "test_helper"

# Every key page renders for the role that should see it.
class PageRenderingTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::AuthHelpers

  setup do
    @requester = create_requester!
    @agent = create_staff!(role: :agent)
    @admin = create_staff!(role: :admin)
    @service_request = create_request!(requester: @requester, status: :in_progress, staff: @agent)
    @service_request.comments.create!(staff_member: @agent, body: "On it.")
  end

  test "landing page" do
    get "/"
    assert_response :ok
    assert_select "a[href='/users/login']"
    assert_select "a[href='/staff_members/login']"
  end

  test "requester portal pages" do
    login_as(@requester, portal: :requester)
    [
      "/requester",
      "/requester/dashboards/overview/cards/in_progress",
      "/requester/dashboards/overview/cards/awaiting_your_confirmation",
      "/requester/dashboards/overview/cards/closed",
      "/requester/service_requests",
      "/requester/service_requests/new",
      "/requester/service_requests/#{@service_request.id}",
      "/requester/service_requests/#{@service_request.id}/nested_comments",
      "/requester/service_requests/#{@service_request.id}/nested_comments/new",
      "/requester/service_requests/#{@service_request.id}/nested_activities"
    ].each do |path|
      get path
      assert_response :ok, "GET #{path} -> #{response.status}"
    end
  end

  test "staff portal pages" do
    login_as(@admin, portal: :staff)
    [
      "/staff",
      "/staff/dashboards/overview/cards/awaiting_triage",
      "/staff/dashboards/overview/cards/unassigned",
      "/staff/dashboards/overview/cards/urgent_and_active",
      "/staff/dashboards/overview/cards/resolved_this_week",
      "/staff/dashboards/overview/cards/requests_by_status",
      "/staff/dashboards/overview/cards/active_by_priority",
      "/staff/service_requests",
      "/staff/service_requests?q[search]=printer",
      "/staff/service_requests/#{@service_request.id}",
      "/staff/service_requests/#{@service_request.id}/edit",
      "/staff/service_requests/#{@service_request.id}/nested_comments/new",
      "/staff/service_requests/#{@service_request.id}/nested_activities",
      "/staff/service_requests/#{@service_request.id}/record_actions/resolve",
      "/staff/service_requests/#{@service_request.id}/record_actions/assign",
      "/staff/staff_members",
      "/staff/staff_members/new",
      "/staff/staff_members/#{@agent.id}",
      "/staff/users",
      "/staff/users/#{@requester.id}"
    ].each do |path|
      get path
      assert_response :ok, "GET #{path} -> #{response.status}"
    end
  end
end
