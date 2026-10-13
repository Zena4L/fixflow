# Requesters only ever see and act on their own requests.
class RequesterPortal::ServiceRequestPolicy < ::ServiceRequestPolicy
  include RequesterPortal::ResourcePolicy

  relation_scope do |relation|
    default_relation_scope(relation).where(requester: user)
  end

  # Core actions

  def create? = true

  # On collection routes `record` is the class; the relation_scope above
  # already limits the list, so only instances need the ownership check.
  def read? = record.is_a?(Class) || own?

  # Editable and deletable only until staff have picked the request up.
  def update? = own? && record.submitted?

  def destroy? = update?

  # Workflow actions

  def close? = own? && record.resolved?

  def reopen? = own? && record.resolved?

  # Core attributes

  def permitted_attributes_for_create
    %i[title description priority]
  end

  def permitted_attributes_for_read
    %i[reference title status priority description assignee resolution_note created_at updated_at resolved_at closed_at]
  end

  def permitted_attributes_for_index
    %i[reference title status priority updated_at]
  end

  # Associations

  def permitted_associations
    %i[comments activities]
  end

  private

  def own? = record.is_a?(ServiceRequest) && record.requester_id == user.id
end
