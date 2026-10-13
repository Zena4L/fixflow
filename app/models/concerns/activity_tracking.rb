# Shared by models that write to the request activity log.
#
# The acting account is either passed explicitly (`record.actor = staff`, as
# the workflow methods do) or taken from Current.actor, which each portal sets
# per request. A nil actor is recorded as a system event.
module ActivityTracking
  extend ActiveSupport::Concern

  included do
    attr_writer :actor
  end

  def actor
    @actor || Current.actor
  end

  private

  def record_activity!(service_request, kind, **attributes)
    service_request.activities.create!(kind:, **Activity.actor_attributes(actor), **attributes)
  end
end
