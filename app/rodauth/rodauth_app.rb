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
    # Autologin from the "Remember me" cookie, but only on the portal that
    # account type uses (whole path segments, so "/staff" is not "/staff_x").
    rodauth(:staff_member).load_memory if portal_path?(r.path, "/staff")
    rodauth(:user).load_memory if portal_path?(r.path, "/requester")

    # ==> Authenticating requests
    # Call `rodauth.require_account` for requests that you want to
    # require authentication for. For example:
    #
    # # authenticate /dashboard/* and /account/* requests
    # if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
    #   rodauth.require_account
    # end
  end

  private

  def portal_path?(path, mount) = path == mount || path.start_with?("#{mount}/")
end
