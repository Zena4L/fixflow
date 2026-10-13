require "test_helper"

# Rodauth's lockout feature (per account) and RodauthController's rate_limit
# (per IP, across accounts).
class BruteForceProtectionTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  ACCOUNTS = {
    "/staff_members" => {portal: "/staff", factory: :create_staff!, lockouts: "staff_member_lockouts"},
    "/users" => {portal: "/requester", factory: :create_requester!, lockouts: "user_lockouts"}
  }.freeze

  ACCOUNTS.each do |prefix, config|
    test "#{prefix}: ten wrong passwords lock the account, even against the right one" do
      account = send(config[:factory])
      10.times { post "#{prefix}/login", params: {email: account.email, password: "wrong-password"} }

      post "#{prefix}/login", params: {email: account.email, password: FactoryHelpers::PASSWORD}
      get config[:portal]
      assert_redirected_to "#{prefix}/login"
      assert lockout_for?(config[:lockouts], account)
    end

    test "#{prefix}: a lockout ends at its deadline" do
      account = send(config[:factory])
      10.times { post "#{prefix}/login", params: {email: account.email, password: "wrong-password"} }
      expire_lockout(config[:lockouts], account)

      post "#{prefix}/login", params: {email: account.email, password: FactoryHelpers::PASSWORD}
      assert_redirected_to config[:portal]
    end
  end

  test "unlocking a deactivated staff member's account does not sign them in" do
    staff = create_staff!
    10.times { post "/staff_members/login", params: {email: staff.email, password: "wrong-password"} }
    staff.update!(active: false)

    perform_enqueued_jobs do
      post "/staff_members/unlock-account-request", params: {email: staff.email}
    end
    link = ActionMailer::Base.deliveries.last.body.to_s[%r{http://\S+/staff_members/unlock-account\S*}]
    assert link, "expected an unlock link in the email"

    get URI(link).request_uri
    follow_redirect! while response.redirect?
    post "/staff_members/unlock-account"

    assert_not lockout_for?("staff_member_lockouts", staff), "the account should be unlocked"
    # Checked on the unlock response itself: StaffPortal would also bounce a
    # later page visit, which would hide an autologin here.
    assert_nil session["staff_member_account_id"], "unlocking must not sign the account in"
  end

  test "login attempts are rate limited per IP across accounts" do
    requester = create_requester!

    with_real_rate_limit_store do
      20.times { |i| post "/users/login", params: {email: "guess-#{i}@example.test", password: "wrong-password"} }

      post "/users/login", params: {email: requester.email, password: FactoryHelpers::PASSWORD}
      assert_redirected_to "/users/login"
      assert_equal "Too many attempts. Please wait a few minutes and try again.", flash[:alert]
      get "/requester"
      assert_redirected_to "/users/login", "a rate-limited login must not sign in"

      get "/users/login"
      assert_response :success, "showing the form is not limited"
    end
  end

  test "requests that send email are rate limited per IP" do
    with_real_rate_limit_store do
      5.times { |i| post "/users/reset-password-request", params: {email: "someone-#{i}@example.test"} }
      assert_no_enqueued_emails do
        post "/users/reset-password-request", params: {email: create_requester!.email}
      end
      assert_equal "Too many attempts. Please wait a few minutes and try again.", flash[:alert]
    end
  end

  private

  def lockout_for?(table, account)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql(["SELECT 1 FROM #{table} WHERE id = ?", account.id])
    ).present?
  end

  def expire_lockout(table, account)
    ActiveRecord::Base.connection.update(
      ActiveRecord::Base.sanitize_sql(["UPDATE #{table} SET deadline = ? WHERE id = ?", 1.minute.ago, account.id])
    )
  end

  # The test environment's cache is a null store, so rate_limit never counts.
  # Back the controllers' store with a real one for the duration of the block.
  def with_real_rate_limit_store
    store = RodauthController.cache_store
    memory = ActiveSupport::Cache::MemoryStore.new
    store.define_singleton_method(:increment) { |*args, **opts| memory.increment(*args, **opts) }
    yield
  ensure
    store.singleton_class.remove_method(:increment) if store.singleton_class.method_defined?(:increment, false)
  end
end
