module RequesterPortal
  module Concerns
    # Portal-wide controller customizations go here.
    # Included by both ResourceController and PlutoniumController.
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)

      # add concerns above.

      included do
        # Attributes activity-log entries to the signed-in requester.
        before_action { Current.actor = current_user }
      end
    end
  end
end
