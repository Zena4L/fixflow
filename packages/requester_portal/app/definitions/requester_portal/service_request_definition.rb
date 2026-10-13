class RequesterPortal::ServiceRequestDefinition < ::ServiceRequestDefinition
  include RequesterPortal::ResourceDefinition

  scope(:awaiting_confirmation) { |scope| scope.resolved }

  filter :status, with: :select, choices: ServiceRequest.statuses.keys.map { |key| [key.humanize, key] }

  action :close, interaction: ServiceRequests::CloseInteraction, label: "Confirm fixed & close"
  action :reopen, interaction: ServiceRequests::ReopenInteraction, label: "Not fixed — reopen"
end
