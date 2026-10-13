# Base policy: denies everything (see ResourcePolicy). Each portal grants
# access in its own subclass under packages/*_portal/app/policies.
class StaffMemberPolicy < ::ResourcePolicy
end
