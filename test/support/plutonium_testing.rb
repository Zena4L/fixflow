# frozen_string_literal: true

# Plutonium::Testing project hooks.
#
# Plutonium's default login helper derives the Rodauth path from the portal
# name (`/requesters/login`), but FixFlow's portals are named after audiences,
# not account tables. Route each account type to its own Rodauth login.
#
# `sign_out` has no equivalent hook and would hit the same wrong path, so tests
# switch users with `reset!` (a fresh integration session) instead.
module PlutoniumTestingOverrides
  RODAUTH_PREFIXES = {"User" => "/users", "StaffMember" => "/staff_members"}.freeze

  def sign_in_for_tests(account, portal:)
    prefix = RODAUTH_PREFIXES.fetch(account.class.name)
    post "#{prefix}/login", params: {email: account.email, password: FactoryHelpers::PASSWORD}
    follow_redirect! if response.redirect?
  end
end

ActiveSupport::TestCase.include(PlutoniumTestingOverrides)
