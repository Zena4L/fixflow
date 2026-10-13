class CreateServiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :service_requests do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.integer :priority, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.belongs_to :requester, null: false, foreign_key: {to_table: :users}
      t.belongs_to :assignee, null: true, foreign_key: {to_table: :staff_members}
      t.text :resolution_note, null: true
      t.datetime :resolved_at, null: true
      t.datetime :closed_at, null: true

      t.timestamps

      # Enum ranges mirror ServiceRequest.priorities / .statuses.
      t.check_constraint "priority BETWEEN 0 AND 3", name: "service_requests_priority_valid"
      t.check_constraint "status BETWEEN 0 AND 4", name: "service_requests_status_valid"
    end
    add_index :service_requests, :priority
    add_index :service_requests, :status
    add_index :service_requests, :created_at
  end
end
