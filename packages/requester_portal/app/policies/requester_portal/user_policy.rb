# Requesters never browse accounts. Without this policy, anything that scopes
# User through the requester portal (e.g. Plutonium's association typeahead,
# /requester/*/typeahead/input/user) falls back to ::UserPolicy, whose default
# relation_scope returns every account.
class RequesterPortal::UserPolicy < ::UserPolicy
  include RequesterPortal::ResourcePolicy

  relation_scope do |relation|
    default_relation_scope(relation).none
  end
end
