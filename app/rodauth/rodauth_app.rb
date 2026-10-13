class RodauthApp < Rodauth::Rails::App
  # auth configuration
  configure ::StaffMemberRodauthPlugin, :staff_member
  configure ::UserRodauthPlugin, :user

  route do |r|
    # this block is running inside of a roda route
    # see https://github.com/jeremyevans/roda#usage-

    # auth route configuration
    r.rodauth(:staff_member)
    r.rodauth(:user)

    # plugin route configuration
    if r.path.start_with?("/staff_member_dashboard")
      rodauth(:staff_member).load_memory # autologin remembered staff_members
    end
    if r.path.start_with?("/user_dashboard")
      rodauth(:user).load_memory # autologin remembered users
    end
    # rodauth.load_memory # autologin remembered users

    # ==> Authenticating requests
    # Call `rodauth.require_account` for requests that you want to
    # require authentication for. For example:
    #
    # # authenticate /dashboard/* and /account/* requests
    # if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
    #   rodauth.require_account
    # end
  end
end
