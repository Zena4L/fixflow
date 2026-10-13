# Columns the pu:rodauth:account generator could not add for us: its
# --extra-attributes option raises NameError in plutonium 0.67.0
# (see docs/decisions.md). Rodauth inserts accounts through Sequel, which
# bypasses ActiveRecord timestamps, so timestamps carry database defaults.
class AddProfileFieldsToAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :name
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    change_table :staff_members, bulk: true do |t|
      t.string :name, null: false, default: ""
      t.integer :role, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
      t.check_constraint "role IN (0, 1)", name: "staff_members_role_valid"
    end
  end
end
