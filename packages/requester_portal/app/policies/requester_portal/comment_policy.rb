# Requesters read public comments on their own requests and add comments to
# them while they are not closed. Comments are never edited or deleted.
class RequesterPortal::CommentPolicy < ::CommentPolicy
  include RequesterPortal::ResourcePolicy

  relation_scope do |relation|
    default_relation_scope(relation)
      .visible_to_requesters
      .where(service_request_id: user.service_requests.select(:id))
  end

  # Core actions

  def create? = parent.is_a?(ServiceRequest) && parent.requester_id == user.id && !parent.closed?

  def read? = record.is_a?(Class) || (!record.internal? && record.service_request.requester_id == user.id)

  def update? = false

  def destroy? = false

  # Core attributes

  def permitted_attributes_for_create
    %i[body]
  end

  def permitted_attributes_for_read
    %i[author_name body created_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
