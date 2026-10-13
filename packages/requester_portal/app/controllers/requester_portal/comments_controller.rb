class RequesterPortal::CommentsController < ::CommentsController
  include RequesterPortal::Concerns::Controller

  private

  # Authorship comes from the session; requesters cannot post internal notes.
  def resource_params
    super.merge(user: current_user, staff_member: nil, internal: false)
  end
end
