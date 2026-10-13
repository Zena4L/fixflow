module ServiceRequests
  class StartInteraction < BaseInteraction
    presents label: "Start work",
      icon: Phlex::TablerIcons::PlayerPlay,
      description: "Begin working on the request (assigns it to you if unassigned)"

    private

    def execute = transition(:in_progress, message: "Work started")
  end
end
