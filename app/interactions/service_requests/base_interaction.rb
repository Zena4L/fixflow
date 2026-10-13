module ServiceRequests
  # Shared plumbing for the workflow buttons. Each subclass is only the
  # presentation (label, inputs, input-shape validation); the rules live in
  # ServiceRequest#transition_to! and the portal policies.
  class BaseInteraction < ::ResourceInteraction
    attribute :resource

    private

    def current_user = view_context.controller.helpers.current_user

    def transition(target, message:, note: nil, changes: {})
      resource.transition_to!(target, actor: current_user, note:, changes:)
      succeed(resource).with_message(message)
    rescue ActiveRecord::RecordInvalid => e
      failed(e.record.errors)
    end
  end
end
