require "test_helper"
require "rake"

class FixflowTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "fixflow:create_admin" }
    Rake::Task["fixflow:create_admin"].reenable
    Rake::Task["fixflow:bootstrap_admin"].reenable
  end

  test "bootstrap_admin creates the first admin from the environment" do
    # The shared test DB may hold seed data (bin/ci seeds it); rolled back after the test.
    StaffMember.admin.update_all(role: StaffMember.roles[:agent])

    with_env("ADMIN_EMAIL" => "First@Example.test", "ADMIN_PASSWORD" => "a-long-secret-123") do
      assert_output(/created staff admin first@example.test/) { Rake::Task["fixflow:bootstrap_admin"].invoke }
    end

    admin = StaffMember.find_by!(email: "first@example.test")
    assert_predicate admin, :admin?
    assert_predicate admin, :verified?
  end

  test "bootstrap_admin never touches an existing admin" do
    existing = create_staff!(role: :admin)

    with_env("ADMIN_EMAIL" => "other@example.test", "ADMIN_PASSWORD" => "a-long-secret-123") do
      assert_no_difference -> { StaffMember.count } do
        Rake::Task["fixflow:bootstrap_admin"].invoke
      end
    end
    assert_predicate existing.reload, :admin?
  end

  test "bootstrap_admin does nothing without credentials or with a short password" do
    StaffMember.admin.update_all(role: StaffMember.roles[:agent]) # see above

    with_env("ADMIN_EMAIL" => nil, "ADMIN_PASSWORD" => nil) do
      assert_no_difference(-> { StaffMember.count }) { Rake::Task["fixflow:bootstrap_admin"].invoke }
    end

    Rake::Task["fixflow:bootstrap_admin"].reenable
    with_env("ADMIN_EMAIL" => "a@example.test", "ADMIN_PASSWORD" => "short") do
      assert_output(nil, /at least 12 characters/) do
        assert_no_difference(-> { StaffMember.count }) { Rake::Task["fixflow:bootstrap_admin"].invoke }
      end
    end
  end

  test "create_admin creates a verified, active admin who can be reset later" do
    with_env("EMAIL" => "boss@example.test", "NAME" => "Boss", "PASSWORD" => "a-long-secret-123") do
      assert_output(/is ready/) { Rake::Task["fixflow:create_admin"].invoke }
    end

    admin = StaffMember.find_by!(email: "boss@example.test")
    assert_predicate admin, :admin?
    assert_predicate admin, :verified?
    assert_predicate admin, :active?
  end

  private

  def with_env(vars)
    old = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each { |key, value| ENV[key] = value }
  end
end
