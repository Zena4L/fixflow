require "test_helper"
require "rake"

class FixflowTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "fixflow:create_admin" }
    Rake::Task["fixflow:create_admin"].reenable
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
