StaffPortal::Engine.routes.draw do
  register_dashboard StaffPortal::OverviewDashboard, at: "/"
  register_resource ::ServiceRequest
  register_resource ::Comment
  register_resource ::Activity
  register_resource ::StaffMember
  register_resource ::User

  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:staff_member) do
    mount StaffPortal::Engine, at: "/staff"
  end
end
