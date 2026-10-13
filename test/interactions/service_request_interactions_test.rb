require "test_helper"

class ServiceRequestInteractionsTest < ActiveSupport::TestCase
  include Plutonium::Testing::ResourceInteraction

  # The interactions read the acting account from the view context.
  ViewContext = Struct.new(:current_user) do
    def controller = self
    def helpers = self
  end

  setup do
    @agent = create_staff!
    @actor = @agent
  end

  def interaction_view_context = ViewContext.new(@actor)

  test "Triage opens a submitted request and can adjust priority atomically" do
    request = create_request!(priority: :low)
    assert_interaction_success(ServiceRequests::TriageInteraction, resource: request, priority: "urgent")

    assert_predicate request.reload, :open?
    assert_predicate request, :urgent?
  end

  test "Triage leaves priority untouched when the move is illegal" do
    request = create_request!(status: :open, staff: @agent, priority: :low)
    assert_interaction_failure(ServiceRequests::TriageInteraction, resource: request, priority: "urgent")

    assert_predicate request.reload, :low?
  end

  test "Triage rejects an unknown priority" do
    request = create_request!
    assert_interaction_failure(ServiceRequests::TriageInteraction, resource: request, priority: "whenever")
    assert_predicate request.reload, :submitted?
  end

  test "Assign requires an active staff member" do
    request = create_request!
    inactive = create_staff!(active: false)

    assert_interaction_failure(ServiceRequests::AssignInteraction, resource: request, assignee_id: inactive.id)
    assert_interaction_failure(ServiceRequests::AssignInteraction, resource: request, assignee_id: nil)
    assert_interaction_success(ServiceRequests::AssignInteraction, resource: request, assignee_id: @agent.id)
    assert_equal @agent, request.reload.assignee
  end

  test "Start assigns the acting staff member" do
    request = create_request!(status: :open, staff: @agent)
    assert_interaction_success(ServiceRequests::StartInteraction, resource: request)

    assert_equal @agent, request.reload.assignee
  end

  test "Resolve requires a note" do
    request = create_request!(status: :in_progress, staff: @agent)

    assert_interaction_failure(ServiceRequests::ResolveInteraction, resource: request, resolution_note: " ")
    assert_interaction_success(ServiceRequests::ResolveInteraction, resource: request, resolution_note: "Done")
    assert_predicate request.reload, :resolved?
  end

  test "Close only works on resolved requests" do
    request = create_request!(status: :in_progress, staff: @agent)
    assert_interaction_failure(ServiceRequests::CloseInteraction, resource: request)

    request.transition_to!(:resolved, actor: @agent, note: "Done")
    assert_interaction_success(ServiceRequests::CloseInteraction, resource: request)
    assert_predicate request.reload, :closed?
  end

  test "Reopen posts the reason as a comment by the actor, atomically" do
    request = create_request!(status: :closed, staff: @agent)
    @actor = request.requester

    assert_interaction_failure(ServiceRequests::ReopenInteraction, resource: request, reason: "")
    assert_interaction_success(ServiceRequests::ReopenInteraction, resource: request, reason: "Broken again")

    assert_predicate request.reload, :open?
    assert_equal ["Reopened: Broken again", request.requester], [request.comments.last.body, request.comments.last.author]
  end
end
