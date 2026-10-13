# frozen_string_literal: true

# Small, explicit builders instead of fixtures: every test states the data it
# depends on.
module FactoryHelpers
  # Matches Plutonium::Testing's default login password.
  PASSWORD = "password123"

  def create_requester!(email: nil, name: "Riley Requester")
    User.create!(email: email || "requester-#{SecureRandom.hex(4)}@example.test",
      name:, password: PASSWORD, status: :verified)
  end

  def create_staff!(role: :agent, email: nil, name: nil, active: true)
    StaffMember.create!(email: email || "#{role}-#{SecureRandom.hex(4)}@example.test",
      name: name || "#{role.to_s.humanize} #{SecureRandom.hex(2)}", role:, active:, password: PASSWORD)
  end

  # Builds a request and walks it through the real workflow to `status`.
  def create_request!(requester: nil, status: :submitted, staff: nil, **attributes)
    requester ||= create_requester!
    request = Current.set(actor: requester) do
      ServiceRequest.create!({title: "Printer is jammed", description: "Paper stuck in tray 2.",
                              priority: :medium, requester:}.merge(attributes))
    end
    advance!(request, to: status, staff: staff || create_staff!)
  end

  # Runs the block in a nested transaction so an expected database error does
  # not poison the test's transaction (Postgres aborts it; SQLite does not).
  def savepoint(&) = ActiveRecord::Base.transaction(requires_new: true, &)

  def advance!(request, to:, staff:)
    path = {
      submitted: [],
      open: %i[open],
      in_progress: %i[open in_progress],
      resolved: %i[open in_progress resolved],
      closed: %i[open in_progress resolved closed]
    }.fetch(to.to_sym)
    path.each do |step|
      request.transition_to!(step, actor: staff, note: ("Fixed it." if step == :resolved))
    end
    request
  end
end

ActiveSupport::TestCase.include(FactoryHelpers)
