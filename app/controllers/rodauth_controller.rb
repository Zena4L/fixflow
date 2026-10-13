# Base rodauth controller. Inherited by all account controllers.
class RodauthController < PlutoniumController
  include Plutonium::Rodauth::ControllerMethods

  # Throttle auth form submissions per IP. Rodauth's lockout feature protects
  # one account at a time; this covers guessing spread across many accounts and
  # endpoints that send email. rodauth-rails runs these callbacks with
  # action_name set to the Rodauth route, so `only:` names routes. Showing a
  # form (GET) is not counted. Counters live in Rails.cache, per account type.
  EMAIL_SENDING_ROUTES = %i[create_account reset_password_request verify_account_resend unlock_account_request].freeze

  rate_limit to: 20, within: 1.minute, name: "login", only: :login,
    if: -> { request.post? }, with: :too_many_attempts
  rate_limit to: 5, within: 10.minutes, name: "email", only: EMAIL_SENDING_ROUTES,
    if: -> { request.post? }, with: :too_many_attempts

  private

  def too_many_attempts
    redirect_to request.path, alert: "Too many attempts. Please wait a few minutes and try again."
  end
end
