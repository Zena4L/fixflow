module ServiceRequests
  class AssignInteraction < BaseInteraction
    presents label: "Assign",
      icon: Phlex::TablerIcons::UserCheck,
      description: "Choose the staff member responsible for this request"

    attribute :assignee_id, :integer
    input :assignee_id, label: "Assignee", as: :select,
      choices: -> { StaffMember.active.order(:name).map { |staff| [staff.to_label, staff.id] } }

    validates :assignee_id, presence: true

    private

    def execute
      assignee = StaffMember.active.find_by(id: assignee_id)
      return failed("must be an active staff member", :assignee_id) unless assignee

      resource.assign_to!(assignee, actor: current_user)
      succeed(resource).with_message("Assigned to #{assignee.to_label}")
    rescue ActiveRecord::RecordInvalid => e
      failed(e.record.errors)
    end
  end
end
