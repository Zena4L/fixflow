class CreateRodauthUserLockout < ActiveRecord::Migration[8.1]
  def change
    # Used by the lockout feature
    create_table :user_login_failures, id: false do |t|
      t.integer :id, primary_key: true
      t.foreign_key :users, column: :id
      t.integer :number, null: false, default: 1
    end
    create_table :user_lockouts, id: false do |t|
      t.integer :id, primary_key: true
      t.foreign_key :users, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent
    end
  end
end
