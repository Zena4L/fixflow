require "test_helper"

class ServiceRequestTest < ActiveSupport::TestCase
  setup do
    @requester = create_requester!
    @agent = create_staff!(role: :agent)
  end

  # --- Creation & validation ---------------------------------------------

  test "a new request starts submitted with a derived reference" do
    request = create_request!(requester: @requester)

    assert_predicate request, :submitted?
    assert_equal format("FF-%05d", request.id), request.reference
    assert_equal "#{request.reference} · Printer is jammed", request.to_label
  end

  test "cannot be created in any status other than submitted" do
    request = ServiceRequest.new(title: "x", description: "y", requester: @requester, status: :resolved)

    assert_not request.valid?
    assert_includes request.errors[:status], "must start as submitted"
  end

  test "requires a title, description and requester" do
    request = ServiceRequest.new

    assert_not request.valid?
    assert_includes request.errors[:title], "can't be blank"
    assert_includes request.errors[:description], "can't be blank"
    assert_includes request.errors[:requester], "must exist"
  end

  test "rejects unknown priorities and over-long titles" do
    request = ServiceRequest.new(title: "a" * 201, description: "y", requester: @requester, priority: "critical")

    assert_not request.valid?
    assert request.errors[:priority].any?
    assert request.errors[:title].any?
  end

  # --- Workflow ------------------------------------------------------------

  test "every legal transition succeeds" do
    ServiceRequest::TRANSITIONS.each do |from, targets|
      targets.each do |to|
        request = create_request!(requester: @requester, status: from, staff: @agent)
        request.transition_to!(to, actor: @agent, note: "Done")

        assert_equal to, request.reload.status, "#{from} -> #{to} should be allowed"
      end
    end
  end

  test "every illegal transition is rejected and leaves the record unchanged" do
    statuses = ServiceRequest.statuses.keys
    statuses.each do |from|
      (statuses - ServiceRequest::TRANSITIONS.fetch(from) - [from]).each do |to|
        request = create_request!(requester: @requester, status: from, staff: @agent)

        error = assert_raises(ActiveRecord::RecordInvalid, "#{from} -> #{to} should be rejected") do
          request.transition_to!(to, actor: @agent, note: "Done")
        end
        assert_match(/cannot change from/, error.message)
        assert_equal from, request.reload.status
        assert_not request.changed?
      end
    end
  end

  test "the workflow is also enforced on plain updates, not just transition_to!" do
    request = create_request!(requester: @requester)

    assert_not request.update(status: :closed)
    assert_equal "submitted", request.reload.status
  end

  test "resolving requires a resolution note and stamps resolved_at" do
    request = create_request!(requester: @requester, status: :in_progress, staff: @agent)

    assert_raises(ActiveRecord::RecordInvalid) { request.transition_to!(:resolved, actor: @agent) }
    assert_nil request.reload.resolved_at

    request.transition_to!(:resolved, actor: @agent, note: "Replaced the cable.")
    assert_equal "Replaced the cable.", request.resolution_note
    assert_not_nil request.resolved_at
  end

  test "starting work assigns the acting staff member when unassigned" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)
    request.transition_to!(:in_progress, actor: @agent)

    assert_equal @agent, request.reload.assignee
  end

  test "work cannot start without an assignee" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)

    # A requester can never be an assignee, so nothing is auto-assigned.
    assert_raises(ActiveRecord::RecordInvalid) { request.transition_to!(:in_progress, actor: @requester) }
    assert_predicate request.reload, :open?
  end

  test "reopening clears the previous outcome" do
    request = create_request!(requester: @requester, status: :closed, staff: @agent)
    request.transition_to!(:open, actor: @requester)

    assert_predicate request, :open?
    assert_nil request.resolved_at
    assert_nil request.closed_at
  end

  test "closed requests are read-only until reopened" do
    request = create_request!(requester: @requester, status: :closed, staff: @agent)

    assert_not request.update(title: "Changed")
    assert_match(/read-only/, request.errors.full_messages.to_sentence)
  end

  test "only active staff can be assigned" do
    request = create_request!(requester: @requester)
    inactive = create_staff!(active: false)

    assert_raises(ActiveRecord::RecordInvalid) { request.assign_to!(inactive, actor: @agent) }
    assert_nil request.reload.assignee
  end

  # --- Activity log --------------------------------------------------------

  test "creation, transitions, assignment and edits are recorded with their actor" do
    request = create_request!(requester: @requester)
    request.assign_to!(@agent, actor: @agent)
    request.transition_to!(:open, actor: @agent)
    Current.set(actor: @agent) { request.update!(priority: :urgent, title: "Printer on fire") }

    log = request.activities.reload.map { |a| [a.kind, a.actor] }
    assert_equal [
      ["created", @requester],
      ["assigned", @agent],
      ["status_changed", @agent],
      ["updated", @agent]
    ], log
    assert_equal %w[title priority].sort, request.activities.last.changeset.keys.sort
  end

  # --- Database constraints (defence in depth) ----------------------------

  test "the database rejects out-of-range statuses and priorities" do
    request = create_request!(requester: @requester)

    # Each violation gets its own savepoint: Postgres aborts the enclosing
    # transaction after an error, SQLite does not.
    assert_raises(ActiveRecord::CheckViolation) { savepoint { request.update_column(:status, 99) } }
    assert_raises(ActiveRecord::CheckViolation) { savepoint { request.update_column(:priority, 99) } }
  end

  test "deleting a request removes its comments and activity" do
    request = create_request!(requester: @requester, status: :open, staff: @agent)
    request.comments.create!(staff_member: @agent, body: "Hello")

    assert_difference -> { Comment.count } => -1, -> { Activity.count } => -request.activities.count do
      request.destroy!
    end
  end
end
