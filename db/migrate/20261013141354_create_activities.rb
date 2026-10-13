class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.belongs_to :service_request, null: false, foreign_key: {on_delete: :cascade}
      t.string :kind, null: false
      t.belongs_to :user, null: true, foreign_key: true
      t.belongs_to :staff_member, null: true, foreign_key: true
      t.string :from_status, null: true
      t.string :to_status, null: true
      t.json :changeset, null: true
      # Mirrors Comment#internal so staff-only events never reach requesters.
      t.boolean :internal, null: false, default: false

      t.timestamps

      # At most one actor; both NULL means a system event.
      t.check_constraint "user_id IS NULL OR staff_member_id IS NULL", name: "activities_single_actor"
    end
    add_index :activities, [:service_request_id, :created_at]
  end
end
