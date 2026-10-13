class StaffPortal::ServiceRequestDefinition < ::ServiceRequestDefinition
  include StaffPortal::ResourceDefinition

  # Queue views (quick filters above the table).
  scope :unassigned
  scope(:mine) { |scope| scope.where(assignee: current_user) }
  scope :submitted
  scope :urgent
  default_scope :active

  filter :status, with: :select, choices: ServiceRequest.statuses.keys.map { |key| [key.humanize, key] }
  filter :priority, with: :select, choices: ServiceRequest.priorities.keys.map { |key| [key.humanize, key] }
  filter :assignee, with: :association, class_name: StaffMember
  filter :requester, with: :association, class_name: User
  filter :created_at, with: :date_range

  # Workflow. Visibility and authorization both come from the policy
  # (triage?, start?, ...), which mirrors ServiceRequest::TRANSITIONS.
  action :triage, interaction: ServiceRequests::TriageInteraction
  action :assign, interaction: ServiceRequests::AssignInteraction
  action :start, interaction: ServiceRequests::StartInteraction
  action :resolve, interaction: ServiceRequests::ResolveInteraction
  action :close, interaction: ServiceRequests::CloseInteraction
  action :reopen, interaction: ServiceRequests::ReopenInteraction
end
