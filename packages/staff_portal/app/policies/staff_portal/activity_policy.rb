# The activity log is read-only for everyone.
class StaffPortal::ActivityPolicy < ::ActivityPolicy
  include StaffPortal::ResourcePolicy

  # Core actions

  def read? = true

  # Core attributes

  def permitted_attributes_for_read
    %i[summary actor_name created_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
