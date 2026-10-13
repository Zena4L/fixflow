# Per-request context. Portals set `actor` to the signed-in account so model
# callbacks can attribute activity-log entries without threading it through.
class Current < ActiveSupport::CurrentAttributes
  attribute :actor
end
