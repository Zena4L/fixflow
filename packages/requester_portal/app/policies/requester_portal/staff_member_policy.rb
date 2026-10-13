# Requesters never browse staff accounts; see RequesterPortal::UserPolicy.
# A request's assignee is still displayed, since that reads the association
# directly rather than through this scope.
class RequesterPortal::StaffMemberPolicy < ::StaffMemberPolicy
  include RequesterPortal::ResourcePolicy

  relation_scope do |relation|
    default_relation_scope(relation).none
  end
end
