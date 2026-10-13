module RequesterPortal
  # Base controller for non-resource pages (dashboard, settings, etc.).
  class PlutoniumController < ::PlutoniumController
    include RequesterPortal::Concerns::Controller
  end
end
