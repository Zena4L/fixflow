require "test_helper"

# Authorization, data-integrity and failure cases enforced on the server,
# independent of what the UI shows.
class AccessControlTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::AuthHelpers

  REFUSED = [302, 403, 404].freeze

  setup do
    @requester = create_requester!
    @other_requester = create_requester!
    @agent = create_staff!(role: :agent)
    @admin = create_staff!(role: :admin)
  end

  # --- Authentication --------------------------------------------------------

  test "portals require their own kind of account" do
    get "/requester/service_requests"
    assert_redirected_to "/users/login"

    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"

    login_as(@requester, portal: :requester)
    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"
  end

  test "staff accounts cannot self-register" do
    get "/staff_members/create-account"
    assert_response :not_found
  end

  # StaffPortal::Concerns::Controller#reject_deactivated_staff
  test "deactivating a staff member ends their open session" do
    login_as(@agent, portal: :staff)
    @agent.update!(active: false)

    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"
    assert_equal "Your staff account has been deactivated.", flash[:alert]
  end

  # StaffMemberRodauthPlugin's before_login. Asserts on the login response
  # itself: the portal check above would also bounce a later page visit, so
  # checking only that would pass even if login were not refused.
  test "deactivated staff cannot sign in" do
    @agent.update!(active: false)

    post "/staff_members/login", params: {email: @agent.email, password: FactoryHelpers::PASSWORD}
    assert_redirected_to "/staff_members/login"
    assert_equal "This staff account has been deactivated.", flash[:alert]

    reset! # fresh session: next user signs in from scratch
    post "/staff_members/login", params: {email: @admin.email, password: FactoryHelpers::PASSWORD}
    assert_redirected_to "/staff", "an active staff member signs in normally"
  end

  # --- Requester isolation ---------------------------------------------------

  test "requesters cannot see or touch someone else's request" do
    theirs = create_request!(requester: @other_requester)
    login_as(@requester, portal: :requester)

    get "/requester/service_requests/#{theirs.id}"
    assert_includes REFUSED, response.status

    patch "/requester/service_requests/#{theirs.id}", params: {service_request: {title: "Mine now"}}
    assert_includes REFUSED, response.status

    delete "/requester/service_requests/#{theirs.id}"
    assert_includes REFUSED, response.status

    post "/requester/service_requests/#{theirs.id}/nested_comments", params: {comment: {body: "Hi"}}
    assert_includes REFUSED, response.status

    assert_equal "Printer is jammed", theirs.reload.title
    assert_empty theirs.comments
  end

  test "the requester list only contains the requester's own requests" do
    mine = create_request!(requester: @requester, title: "My laptop")
    create_request!(requester: @other_requester, title: "Their secret thing")
    login_as(@requester, portal: :requester)

    get "/requester/service_requests"
    assert_includes response.body, mine.title
    assert_not_includes response.body, "Their secret thing"
  end

  test "internal staff notes never reach requesters" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)
    internal = request.comments.create!(staff_member: @agent, body: "Internal: VIP, handle carefully", internal: true)
    login_as(@requester, portal: :requester)

    get "/requester/service_requests/#{request.id}/nested_comments"
    assert_not_includes response.body, "VIP, handle carefully"

    get "/requester/service_requests/#{request.id}/nested_comments/#{internal.id}"
    assert_includes REFUSED, response.status

    get "/requester/service_requests/#{request.id}/nested_activities"
    assert_not_includes response.body, "internal note"
  end

  # Plutonium's typeahead endpoint accepts any association name on the resource
  # and scopes the target through the portal's policy for that class.
  test "requesters cannot list accounts through association typeahead" do
    create_requester!(name: "Victim Person", email: "victim@example.test")
    login_as(@requester, portal: :requester)

    %w[
      /requester/comments/typeahead/input/user
      /requester/comments/typeahead/input/staff_member
      /requester/activities/typeahead/input/user
      /requester/activities/typeahead/input/staff_member
      /requester/service_requests/typeahead/input/requester
      /requester/service_requests/typeahead/input/assignee
    ].each do |path|
      get path
      assert_response :success
      assert_empty response.parsed_body["results"], "#{path} leaked accounts"
    end
  end

  test "staff can still look up staff and requesters through typeahead" do
    login_as(@agent, portal: :staff)

    get "/staff/service_requests/typeahead/filter/assignee", params: {q: @admin.name}
    assert_includes response.parsed_body["results"].pluck("label"), @admin.name

    get "/staff/service_requests/typeahead/filter/requester", params: {q: @requester.name}
    assert_includes response.parsed_body["results"].pluck("label"), @requester.name
  end

  # --- Mass-assignment / forged params ----------------------------------------

  test "forged workflow and ownership params are ignored on create" do
    login_as(@requester, portal: :requester)
    post "/requester/service_requests", params: {service_request: {
      title: "Legit", description: "Legit", priority: "low",
      status: "closed", requester_id: @other_requester.id, requester: @other_requester.to_sgid.to_s,
      assignee_id: @agent.id, resolution_note: "Pre-resolved"
    }}

    request = ServiceRequest.last
    assert_equal @requester, request.requester
    assert_predicate request, :submitted?
    assert_nil request.assignee
    assert_nil request.resolution_note
  end

  test "forged authorship and internal flags are ignored on requester comments" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)
    login_as(@requester, portal: :requester)

    post "/requester/service_requests/#{request.id}/nested_comments", params: {comment: {
      body: "Hello", internal: "1", staff_member_id: @agent.id, user_id: @other_requester.id
    }}

    comment = request.comments.reload.last
    assert_equal @requester, comment.author
    assert_not comment.internal?
  end

  test "staff cannot change status through the edit form" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)
    login_as(@agent, portal: :staff)

    patch "/staff/service_requests/#{request.id}", params: {service_request: {title: "Renamed", status: "closed"}}
    assert_equal "Renamed", request.reload.title
    assert_predicate request, :open?
  end

  # --- Editing / deletion rules ----------------------------------------------

  test "requesters can edit and delete only while the request is submitted" do
    submitted = create_request!(requester: @requester)
    triaged = create_request!(requester: @requester, status: :open, staff: @agent)
    login_as(@requester, portal: :requester)

    patch "/requester/service_requests/#{triaged.id}", params: {service_request: {title: "Changed"}}
    assert_includes REFUSED, response.status
    assert_equal "Printer is jammed", triaged.reload.title

    assert_no_difference -> { ServiceRequest.count } do
      delete "/requester/service_requests/#{triaged.id}"
    end

    assert_difference -> { ServiceRequest.count }, -1 do
      delete "/requester/service_requests/#{submitted.id}"
    end
  end

  test "only admins can delete requests" do
    request = create_request!(requester: @requester)

    login_as(@agent, portal: :staff)
    assert_no_difference -> { ServiceRequest.count } do
      delete "/staff/service_requests/#{request.id}"
    end

    reset! # fresh session: next user signs in from scratch
    login_as(@admin, portal: :staff)
    assert_difference -> { ServiceRequest.count }, -1 do
      delete "/staff/service_requests/#{request.id}"
    end
  end

  test "staff cannot create requests" do
    login_as(@admin, portal: :staff)

    assert_no_difference -> { ServiceRequest.count } do
      post "/staff/service_requests", params: {service_request: {title: "x", description: "y", priority: "low"}}
    end
    assert_includes REFUSED, response.status
  end

  test "closed requests cannot be edited or commented on" do
    request = create_request!(requester: @requester, status: :closed, staff: @agent)
    login_as(@agent, portal: :staff)

    patch "/staff/service_requests/#{request.id}", params: {service_request: {title: "Changed"}}
    assert_includes REFUSED, response.status

    post "/staff/service_requests/#{request.id}/nested_comments", params: {comment: {body: "Late note"}}
    assert_includes REFUSED, response.status
    assert_empty request.comments.reload
  end

  # --- Workflow enforcement over HTTP --------------------------------------------

  test "workflow steps cannot be skipped by calling the action directly" do
    request = create_request!(requester: @requester)
    login_as(@agent, portal: :staff)

    post "/staff/service_requests/#{request.id}/record_actions/resolve", params: {interaction: {resolution_note: "Skip!"}}
    assert_includes REFUSED, response.status

    post "/staff/service_requests/#{request.id}/record_actions/start"
    assert_includes REFUSED, response.status

    assert_predicate request.reload, :submitted?
  end

  test "requesters cannot trigger staff-only workflow actions" do
    request = create_request!(requester: @requester)
    login_as(@requester, portal: :requester)

    post "/requester/service_requests/#{request.id}/record_actions/triage"
    assert_includes REFUSED, response.status
    assert_predicate request.reload, :submitted?
  end

  # --- Validation & error states ------------------------------------------------

  test "invalid submissions re-render the form with errors" do
    login_as(@requester, portal: :requester)

    assert_no_difference -> { ServiceRequest.count } do
      post "/requester/service_requests", params: {service_request: {title: "", description: "", priority: "medium"}}
    end
    assert_response :unprocessable_content
    assert_includes response.body, "can&#39;t be blank"
  end

  test "resolving without a note is rejected with an error" do
    request = create_request!(requester: @requester, status: :in_progress, staff: @agent)
    login_as(@agent, portal: :staff)

    post "/staff/service_requests/#{request.id}/record_actions/resolve", params: {interaction: {resolution_note: ""}}
    assert_response :unprocessable_content
    assert_predicate request.reload, :in_progress?
  end

  # --- Staff management -------------------------------------------------------

  test "only admins can add staff members" do
    params = {staff_member: {name: "New Hire", email: "new@example.test", role: "agent", active: "1"}}

    login_as(@agent, portal: :staff)
    assert_no_difference -> { StaffMember.count } do
      post "/staff/staff_members", params:
    end

    reset! # fresh session: next user signs in from scratch
    login_as(@admin, portal: :staff)
    assert_difference -> { StaffMember.count }, 1 do
      post "/staff/staff_members", params:
    end
    assert_predicate StaffMember.find_by(email: "new@example.test"), :verified?
  end

  test "a duplicate staff email is a validation error, not a crash" do
    login_as(@admin, portal: :staff)

    assert_no_difference -> { StaffMember.count } do
      post "/staff/staff_members", params: {staff_member: {name: "Dup", email: @agent.email.upcase, role: "agent", active: "1"}}
    end
    assert_response :unprocessable_content

    patch "/staff/staff_members/#{@agent.id}", params: {staff_member: {email: @admin.email}}
    assert_response :unprocessable_content
    assert_not_equal @admin.email, @agent.reload.email
  end

  test "staff added with a mixed-case email can sign in" do
    login_as(@admin, portal: :staff)
    post "/staff/staff_members", params: {staff_member: {name: "Casey", email: "  Casey.Case@Example.TEST ", role: "agent", active: "1"}}
    StaffMember.find_by!(email: "casey.case@example.test").update!(password: FactoryHelpers::PASSWORD)

    reset! # fresh session: next user signs in from scratch
    post "/staff_members/login", params: {email: "Casey.Case@example.test", password: FactoryHelpers::PASSWORD}
    assert_redirected_to "/staff"
  end
end
