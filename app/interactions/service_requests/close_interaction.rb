module ServiceRequests
  class CloseInteraction < BaseInteraction
    presents label: "Close",
      icon: Phlex::TablerIcons::Lock,
      description: "Confirm the resolution and close the request"

    private

    def execute = transition(:closed, message: "Request closed")
  end
end
