module RequesterPortal
  # Base controller for portal resources when no feature package controller exists.
  # Add customizations to Concerns::Controller, not here.
  class ResourceController < ::ResourceController
    include RequesterPortal::Concerns::Controller
  end
end
