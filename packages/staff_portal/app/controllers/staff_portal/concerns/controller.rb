module StaffPortal
  module Concerns
    # Portal-wide controller customizations go here.
    # Included by both ResourceController and PlutoniumController.
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:staff_member)

      # add concerns above.

      included do
        before_action :reject_deactivated_staff
        # Attributes activity-log entries to the signed-in staff member.
        before_action { Current.actor = current_user }
      end

      private

      # Deactivation takes effect immediately, even for an open session.
      def reject_deactivated_staff
        return if current_user.active?

        rodauth(:staff_member).logout
        redirect_to rodauth(:staff_member).login_path, alert: "Your staff account has been deactivated."
      end
    end
  end
end
