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

ActiveRecord::Schema[7.2].define(version: 2025_05_01_121314) do
  create_table "budgets", force: :cascade do |t|
    t.string "name"
    t.decimal "amount"
    t.date "start_date"
    t.date "end_date"
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.string "recurrence"
    t.integer "notification_threshold"
    t.text "notes"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "category_type"
    t.string "color"
    t.string "icon"
    t.integer "user_id"
    t.boolean "is_default"
    t.integer "parent_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount"
    t.string "description"
    t.date "transaction_date"
    t.string "transaction_type"
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.string "payment_method"
    t.string "status"
    t.text "notes"
    t.string "receipt_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "first_name"
    t.string "last_name"
    t.date "date_of_birth"
    t.string "phone"
    t.string "currency_preference"
    t.string "time_zone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "users"
end
