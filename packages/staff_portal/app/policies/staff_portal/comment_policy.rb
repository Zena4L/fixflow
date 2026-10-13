# Staff can comment (publicly or as an internal note) on any request that is
# not closed. Comments are never edited or deleted.
class StaffPortal::CommentPolicy < ::CommentPolicy
  include StaffPortal::ResourcePolicy

  # Core actions

  def create? = parent.is_a?(ServiceRequest) && !parent.closed?

  def read? = true

  def update? = false

  def destroy? = false

  # Core attributes

  def permitted_attributes_for_create
    %i[body internal]
  end

  def permitted_attributes_for_read
    %i[author_name internal body created_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
