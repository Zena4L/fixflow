# Every staff member can see the team; only admins manage it. Accounts are
# deactivated rather than deleted so history stays attributable.
class StaffPortal::StaffMemberPolicy < ::StaffMemberPolicy
  include StaffPortal::ResourcePolicy

  # Core actions

  def create? = user.admin?

  def read? = true

  def update? = user.admin?

  def destroy? = false

  # Core attributes

  def permitted_attributes_for_create
    %i[name email role active]
  end

  # Admins cannot demote or deactivate themselves (avoids locking everyone out).
  def permitted_attributes_for_update
    (record == user) ? %i[name email] : %i[name email role active]
  end

  def permitted_attributes_for_read
    %i[name email role active created_at]
  end

  def permitted_attributes_for_index
    %i[name email role active]
  end

  # Associations

  def permitted_associations
    %i[assigned_requests]
  end
end
