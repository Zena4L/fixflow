module ServiceRequests
  class ResolveInteraction < BaseInteraction
    presents label: "Resolve",
      icon: Phlex::TablerIcons::CircleCheck,
      description: "Mark the request as resolved and tell the requester what was done"

    attribute :resolution_note, :string
    input :resolution_note, as: :text, hint: "Visible to the requester."

    validates :resolution_note, presence: true, length: {maximum: 5_000}

    private

    def execute = transition(:resolved, note: resolution_note, message: "Request resolved")
  end
end
