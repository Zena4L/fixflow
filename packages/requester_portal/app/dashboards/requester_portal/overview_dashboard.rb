module RequesterPortal
  class OverviewDashboard < Plutonium::Dashboard::Base
    presents label: "Overview", description: "Your requests at a glance"

    metric(:in_progress, icon: Phlex::TablerIcons::Loader,
      href: -> { resource_url_for(::ServiceRequest, parent: nil, q: {scope: :active}) }) do
      requests.active.count
    end
    metric(:awaiting_your_confirmation, icon: Phlex::TablerIcons::Checklist,
      href: -> { resource_url_for(::ServiceRequest, parent: nil, q: {scope: :awaiting_confirmation}) }) do
      requests.resolved.count
    end
    metric(:closed, icon: Phlex::TablerIcons::Lock) { requests.closed.count }

    # The documented dashboard `link` toolbar macro is not in plutonium 0.67.0,
    # so the call to action is a card (see docs/decisions.md).
    card(:need_help, span: :full, lazy: false) do
      p(class: "mb-4 text-[var(--pu-text-muted)]") { "Something not working? Tell us and we will pick it up." }
      a(href: new_request_url, class: "pu-btn pu-btn-md pu-btn-primary") { "Submit a new request" }
    end

    private

    # authorized_resource_scope applies the portal policy's relation_scope,
    # so a requester only ever counts their own requests.
    def requests = authorized_resource_scope(::ServiceRequest)

    def new_request_url = resource_url_for(::ServiceRequest, action: :new, parent: nil)
  end
end
