# Staff can look up requesters (read-only); requester accounts manage
# themselves through Rodauth.
class StaffPortal::UserPolicy < ::UserPolicy
  include StaffPortal::ResourcePolicy

  # Core actions

  def read? = true

  # Core attributes

  def permitted_attributes_for_read
    %i[name email status created_at]
  end

  def permitted_attributes_for_index
    %i[name email status]
  end

  # Associations

  def permitted_associations
    %i[service_requests]
  end
end
