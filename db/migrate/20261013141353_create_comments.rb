class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.belongs_to :service_request, null: false, foreign_key: {on_delete: :cascade}
      t.text :body, null: false
      t.boolean :internal, null: false, default: false
      t.belongs_to :user, null: true, foreign_key: true
      t.belongs_to :staff_member, null: true, foreign_key: true

      t.timestamps

      # Exactly one author: a requester (user) or a staff member.
      t.check_constraint "(user_id IS NULL) <> (staff_member_id IS NULL)", name: "comments_single_author"
      # Internal notes are staff-only.
      t.check_constraint "internal = FALSE OR staff_member_id IS NOT NULL", name: "comments_internal_by_staff"
    end
  end
end
