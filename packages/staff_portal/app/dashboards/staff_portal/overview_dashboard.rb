module StaffPortal
  class OverviewDashboard < Plutonium::Dashboard::Base
    presents label: "Overview", description: "The state of the request queue"

    metric(:awaiting_triage, icon: Phlex::TablerIcons::Inbox,
      href: -> { resource_url_for(::ServiceRequest, parent: nil, q: {scope: :submitted}) }) do
      requests.submitted.count
    end
    metric(:unassigned, icon: Phlex::TablerIcons::UserQuestion,
      href: -> { resource_url_for(::ServiceRequest, parent: nil, q: {scope: :unassigned}) }) do
      requests.active.unassigned.count
    end
    metric(:urgent_and_active, icon: Phlex::TablerIcons::AlertTriangle, positive: :down) do
      requests.active.urgent.count
    end
    metric(:resolved_this_week, icon: Phlex::TablerIcons::CircleCheck) do
      {value: requests.where(resolved_at: 7.days.ago..).count,
       previous: requests.where(resolved_at: 14.days.ago...7.days.ago).count,
       change_label: "vs. previous 7 days"}
    end

    chart(:requests_by_status, type: :donut, span: 6) do
      requests.group(:status).count.transform_keys(&:humanize)
    end
    chart(:active_by_priority, type: :column, span: 6) do
      requests.active.group(:priority).count.transform_keys(&:humanize)
    end

    private

    def requests = authorized_resource_scope(::ServiceRequest)
  end
end
