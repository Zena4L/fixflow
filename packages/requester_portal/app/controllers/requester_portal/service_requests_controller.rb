class RequesterPortal::ServiceRequestsController < ::ServiceRequestsController
  include RequesterPortal::Concerns::Controller

  private

  # The requester is always the signed-in user, never a submitted value.
  def resource_params
    super.merge(requester: current_user)
  end
end
