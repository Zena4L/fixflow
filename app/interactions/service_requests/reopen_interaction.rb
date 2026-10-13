module ServiceRequests
  class ReopenInteraction < BaseInteraction
    presents label: "Reopen",
      icon: Phlex::TablerIcons::RotateClockwise,
      description: "Send the request back to the queue"

    attribute :reason, :string
    input :reason, as: :text, hint: "Explain what is still wrong. Posted as a comment."

    validates :reason, presence: true, length: {maximum: 5_000}

    private

    def execute
      ServiceRequest.transaction do
        transition(:open, message: "Request reopened").and_then do |request|
          request.comments.create!(body: "Reopened: #{reason}", **Activity.actor_attributes(current_user))
          succeed(request).with_message("Request reopened")
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      failed(e.record.errors)
    end
  end
end
