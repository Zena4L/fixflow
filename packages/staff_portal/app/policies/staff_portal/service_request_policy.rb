# Staff see every request. Agents and admins work the queue; only admins
# delete. Workflow predicates mirror ServiceRequest::TRANSITIONS, which the
# model enforces again on save.
class StaffPortal::ServiceRequestPolicy < ::ServiceRequestPolicy
  include StaffPortal::ResourcePolicy

  # Core actions

  # Requests are raised by requesters; staff never create them.
  def create? = false

  def read? = true

  def update? = !record.closed?

  def destroy? = user.admin?

  # Workflow actions

  def triage? = record.submitted?

  def assign? = !record.closed?

  def start? = record.open?

  def resolve? = record.in_progress?

  def close? = record.resolved?

  def reopen? = record.reopenable?

  # Core attributes

  def permitted_attributes_for_create
    %i[title description priority]
  end

  def permitted_attributes_for_read
    %i[reference title status priority description requester assignee resolution_note created_at updated_at resolved_at closed_at]
  end

  def permitted_attributes_for_index
    %i[reference title status priority requester assignee updated_at]
  end

  # Associations

  def permitted_associations
    %i[comments activities]
  end
end
