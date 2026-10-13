# frozen_string_literal: true

require "test_helper"

class StaffPortal::ServiceRequestTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::ResourceCrud
  include Plutonium::Testing::ResourcePolicy
  include Plutonium::Testing::ResourceDefinition

  # Staff never create requests (requesters do), so new/create are not routes
  # staff can use; that refusal is asserted in StaffWorkflowTest.
  resource_tests_for ServiceRequest,
    portal: :staff,
    skip: %i[new create]

  setup do
    @account = create_staff!(role: :admin)
    @agent = create_staff!(role: :agent)
    login_as(@account)
  end

  def create_resource!
    create_request!
  end

  def valid_create_params
    {}
  end

  def valid_update_params
    {title: "Retitled by staff", priority: "low"}
  end

  def policy_roles
    {admin: -> { @account }, agent: -> { @agent }}
  end

  def policy_record
    create_resource!
  end

  def policy_matrix
    {
      index: %i[admin agent],
      show: %i[admin agent],
      create: %i[],
      update: %i[admin agent],
      destroy: %i[admin],
      triage: %i[admin agent],
      assign: %i[admin agent],
      start: %i[],
      resolve: %i[]
    }
  end

  private

  # Test the portal's policy, where the staff rules live.
  def policy_class_for(_record) = StaffPortal::ServiceRequestPolicy
end
