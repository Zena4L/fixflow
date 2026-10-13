class StaffPortal::CommentsController < ::CommentsController
  include StaffPortal::Concerns::Controller

  private

  # Authorship comes from the session, never from submitted params.
  def resource_params
    super.merge(staff_member: current_user, user: nil)
  end
end
