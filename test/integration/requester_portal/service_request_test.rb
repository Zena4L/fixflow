# frozen_string_literal: true

require "test_helper"

class RequesterPortal::ServiceRequestTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::ResourceCrud
  include Plutonium::Testing::ResourcePolicy
  include Plutonium::Testing::ResourceDefinition

  resource_tests_for ServiceRequest,
    portal: :requester

  setup do
    @account = create_requester!
    @other_requester = create_requester!
    login_as(@account)
  end

  # A freshly submitted request is the only state a requester may edit/delete.
  def create_resource!
    create_request!(requester: @account)
  end

  def valid_create_params
    {title: "Monitor flickers", description: "The left monitor flickers every few seconds.", priority: "high"}
  end

  def valid_update_params
    {title: "Monitor flickers constantly", priority: "urgent"}
  end

  def policy_roles
    {owner: -> { @account }, other_requester: -> { @other_requester }}
  end

  def policy_record
    create_resource!
  end

  def policy_matrix
    {
      index: %i[owner],
      show: %i[owner],
      create: %i[owner other_requester],
      update: %i[owner],
      destroy: %i[owner]
    }
  end

  private

  # Test the portal's policy, where the requester rules live.
  def policy_class_for(_record) = RequesterPortal::ServiceRequestPolicy
end
