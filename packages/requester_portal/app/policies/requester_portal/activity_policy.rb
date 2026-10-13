# The activity log is read-only and hides staff-internal events.
class RequesterPortal::ActivityPolicy < ::ActivityPolicy
  include RequesterPortal::ResourcePolicy

  relation_scope do |relation|
    default_relation_scope(relation)
      .visible_to_requesters
      .where(service_request_id: user.service_requests.select(:id))
  end

  # Core actions

  def read? = record.is_a?(Class) || (!record.internal? && record.service_request.requester_id == user.id)

  # Core attributes

  def permitted_attributes_for_read
    %i[summary actor_name created_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
