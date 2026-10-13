require "test_helper"

# "Remember me" restores a session from the remember cookie once the session
# cookie is gone (browser restart, expiry). Each test drops the session cookie
# to simulate that.
class RememberMeTest < ActionDispatch::IntegrationTest
  setup do
    @requester = create_requester!
    @agent = create_staff!
  end

  test "a remembered staff member is signed back in to the staff portal" do
    sign_in("/staff_members", @agent, remember: true)
    drop_session_cookie

    get "/staff/service_requests"
    assert_response :success
  end

  test "without remember me, a lost session means signing in again" do
    sign_in("/staff_members", @agent, remember: false)
    drop_session_cookie

    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"
  end

  test "a remembered requester is signed back in to the requester portal" do
    sign_in("/users", @requester, remember: true)
    drop_session_cookie

    get "/requester/service_requests"
    assert_response :success
  end

  test "remembered logins for both portals coexist without evicting each other" do
    sign_in("/users", @requester, remember: true)
    sign_in("/staff_members", @agent, remember: true)
    drop_session_cookie

    get "/requester/service_requests"
    assert_response :success
    get "/staff/service_requests"
    assert_response :success
    get "/requester/service_requests"
    assert_response :success
  end

  test "a deactivated staff member's remember cookie is refused and discarded" do
    sign_in("/staff_members", @agent, remember: true)
    @agent.update!(active: false)
    drop_session_cookie

    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"
    assert_equal "This staff account has been deactivated.", flash[:alert]
    assert_predicate cookies["_staff_member_remember"], :blank?
    assert_not remember_key_stored?(@agent), "the remember key should be deleted, not just the cookie"

    get "/staff/service_requests"
    assert_redirected_to "/staff_members/login"
  end

  private

  def sign_in(prefix, account, remember:)
    params = {email: account.email, password: FactoryHelpers::PASSWORD}
    params[:remember] = "remember" if remember
    post "#{prefix}/login", params: params
    assert_response :redirect
  end

  def remember_key_stored?(staff)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql(["SELECT 1 FROM staff_member_remember_keys WHERE id = ?", staff.id])
    ).present?
  end

  def drop_session_cookie
    cookies.delete(Rails.application.config.session_options.fetch(:key))
  end
end
