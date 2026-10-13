RequesterPortal::Engine.routes.draw do
  register_dashboard RequesterPortal::OverviewDashboard, at: "/"
  register_resource ::ServiceRequest
  register_resource ::Comment
  register_resource ::Activity

  # register resources above.

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end

# mount our app
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    mount RequesterPortal::Engine, at: "/requester"
  end
end
