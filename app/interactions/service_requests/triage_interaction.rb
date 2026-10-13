module ServiceRequests
  class TriageInteraction < BaseInteraction
    presents label: "Accept",
      icon: Phlex::TablerIcons::Inbox,
      description: "Accept the request into the queue, optionally adjusting its priority"

    attribute :priority, :string
    input :priority, as: :select, choices: -> { ServiceRequest.priorities.keys.map { |key| [key.humanize, key] } }

    validates :priority, inclusion: {in: ServiceRequest.priorities.keys}, allow_blank: true

    private

    def execute
      transition(:open, message: "Request accepted", changes: priority.present? ? {priority:} : {})
    end
  end
end
