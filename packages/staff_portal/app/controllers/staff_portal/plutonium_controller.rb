module StaffPortal
  # Base controller for non-resource pages (dashboard, settings, etc.).
  class PlutoniumController < ::PlutoniumController
    include StaffPortal::Concerns::Controller
  end
end
