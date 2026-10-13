# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_13_141354) do
  create_table "activities", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.string "kind", null: false
    t.integer "user_id"
    t.integer "staff_member_id"
    t.string "from_status"
    t.string "to_status"
    t.json "changeset"
    t.boolean "internal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_request_id", "created_at"], name: "index_activities_on_service_request_id_and_created_at"
    t.index ["service_request_id"], name: "index_activities_on_service_request_id"
    t.index ["staff_member_id"], name: "index_activities_on_staff_member_id"
    t.index ["user_id"], name: "index_activities_on_user_id"
    t.check_constraint "user_id IS NULL OR staff_member_id IS NULL", name: "activities_single_actor"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "service_request_id", null: false
    t.text "body", null: false
    t.boolean "internal", default: false, null: false
    t.integer "user_id"
    t.integer "staff_member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_request_id"], name: "index_comments_on_service_request_id"
    t.index ["staff_member_id"], name: "index_comments_on_staff_member_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.check_constraint "(user_id IS NULL) <> (staff_member_id IS NULL)", name: "comments_single_author"
    t.check_constraint "internal = FALSE OR staff_member_id IS NOT NULL", name: "comments_internal_by_staff"
  end

  create_table "service_requests", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.integer "priority", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.integer "requester_id", null: false
    t.integer "assignee_id"
    t.text "resolution_note"
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_service_requests_on_assignee_id"
    t.index ["created_at"], name: "index_service_requests_on_created_at"
    t.index ["priority"], name: "index_service_requests_on_priority"
    t.index ["requester_id"], name: "index_service_requests_on_requester_id"
    t.index ["status"], name: "index_service_requests_on_status"
    t.check_constraint "priority BETWEEN 0 AND 3", name: "service_requests_priority_valid"
    t.check_constraint "status BETWEEN 0 AND 4", name: "service_requests_status_valid"
  end

  create_table "staff_member_login_change_keys", force: :cascade do |t|
    t.string "key", null: false
    t.string "login", null: false
    t.datetime "deadline", null: false
  end

  create_table "staff_member_password_reset_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "staff_member_remember_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
  end

  create_table "staff_members", force: :cascade do |t|
    t.integer "status", default: 1, null: false
    t.string "email", null: false
    t.string "password_hash"
    t.string "name", default: "", null: false
    t.integer "role", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["email"], name: "index_staff_members_on_email", unique: true, where: "status IN (1, 2)"
    t.check_constraint "role IN (0, 1)", name: "staff_members_role_valid"
  end

  create_table "user_login_change_keys", force: :cascade do |t|
    t.string "key", null: false
    t.string "login", null: false
    t.datetime "deadline", null: false
  end

  create_table "user_password_reset_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "user_remember_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
  end

  create_table "user_verification_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.integer "status", default: 1, null: false
    t.string "email", null: false
    t.string "password_hash"
    t.string "name"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "status IN (1, 2)"
  end

  add_foreign_key "activities", "service_requests", on_delete: :cascade
  add_foreign_key "activities", "staff_members"
  add_foreign_key "activities", "users"
  add_foreign_key "comments", "service_requests", on_delete: :cascade
  add_foreign_key "comments", "staff_members"
  add_foreign_key "comments", "users"
  add_foreign_key "service_requests", "staff_members", column: "assignee_id"
  add_foreign_key "service_requests", "users", column: "requester_id"
  add_foreign_key "staff_member_login_change_keys", "staff_members", column: "id"
  add_foreign_key "staff_member_password_reset_keys", "staff_members", column: "id"
  add_foreign_key "staff_member_remember_keys", "staff_members", column: "id"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_remember_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
