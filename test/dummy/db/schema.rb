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

ActiveRecord::Schema[8.1].define(version: 2025_10_24_211658) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "scheduling_availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.time "end_time", null: false
    t.bigint "schedule_id", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["schedule_id", "day_of_week"], name: "index_scheduling_availabilities_on_schedule_id_and_day_of_week"
    t.index ["schedule_id"], name: "index_scheduling_availabilities_on_schedule_id"
  end

  create_table "scheduling_booking_answers", force: :cascade do |t|
    t.text "answer"
    t.bigint "booking_id", null: false
    t.bigint "booking_question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "booking_question_id"], name: "index_booking_answers_on_booking_and_question"
    t.index ["booking_id"], name: "index_scheduling_booking_answers_on_booking_id"
    t.index ["booking_question_id"], name: "index_scheduling_booking_answers_on_booking_question_id"
  end

  create_table "scheduling_booking_changes", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "change_type", null: false
    t.datetime "created_at", null: false
    t.string "initiated_by"
    t.datetime "new_end_time"
    t.datetime "new_start_time"
    t.datetime "old_end_time"
    t.datetime "old_start_time"
    t.text "reason"
    t.datetime "updated_at", null: false
    t.index ["booking_id", "change_type"], name: "index_scheduling_booking_changes_on_booking_id_and_change_type"
    t.index ["booking_id"], name: "index_scheduling_booking_changes_on_booking_id"
    t.index ["created_at"], name: "index_scheduling_booking_changes_on_created_at"
  end

  create_table "scheduling_booking_questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_type_id", null: false
    t.text "help_text"
    t.string "label", null: false
    t.text "options"
    t.text "placeholder"
    t.integer "position", default: 0
    t.string "question_type", null: false
    t.boolean "required", default: false
    t.datetime "updated_at", null: false
    t.index ["event_type_id", "position"], name: "idx_on_event_type_id_position_ded9a11cd7"
    t.index ["event_type_id"], name: "index_scheduling_booking_questions_on_event_type_id"
  end

  create_table "scheduling_bookings", force: :cascade do |t|
    t.string "cancellation_reason"
    t.string "cancellation_token"
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.bigint "event_type_id", null: false
    t.string "google_calendar_event_id"
    t.string "locale", default: "es"
    t.bigint "member_id", null: false
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.string "outlook_calendar_event_id"
    t.string "payment_status", default: "not_required"
    t.string "reschedule_token"
    t.bigint "rescheduled_from_id"
    t.datetime "start_time", null: false
    t.string "status", default: "confirmed"
    t.string "timezone", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["cancellation_token"], name: "index_scheduling_bookings_on_cancellation_token", unique: true
    t.index ["client_id", "start_time"], name: "index_scheduling_bookings_on_client_id_and_start_time"
    t.index ["client_id"], name: "index_scheduling_bookings_on_client_id"
    t.index ["event_type_id"], name: "index_scheduling_bookings_on_event_type_id"
    t.index ["member_id", "start_time"], name: "index_scheduling_bookings_on_member_id_and_start_time"
    t.index ["member_id"], name: "index_scheduling_bookings_on_member_id"
    t.index ["payment_status"], name: "index_scheduling_bookings_on_payment_status"
    t.index ["reschedule_token"], name: "index_scheduling_bookings_on_reschedule_token", unique: true
    t.index ["rescheduled_from_id"], name: "index_scheduling_bookings_on_rescheduled_from_id"
    t.index ["status"], name: "index_scheduling_bookings_on_status"
    t.index ["uid"], name: "index_scheduling_bookings_on_uid", unique: true
  end

  create_table "scheduling_calendar_connections", force: :cascade do |t|
    t.text "access_token"
    t.boolean "active", default: true
    t.boolean "add_bookings_to_calendar", default: true
    t.boolean "check_for_conflicts", default: true
    t.datetime "created_at", null: false
    t.string "external_calendar_id"
    t.bigint "member_id", null: false
    t.string "provider", null: false
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["member_id", "provider"], name: "idx_on_member_id_provider_25cf53a966", unique: true
    t.index ["member_id"], name: "index_scheduling_calendar_connections_on_member_id"
  end

  create_table "scheduling_clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "locale", default: "es"
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.bigint "organization_id", null: false
    t.string "phone"
    t.string "timezone", default: "America/Lima"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_scheduling_clients_on_email"
    t.index ["organization_id", "email"], name: "index_scheduling_clients_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_scheduling_clients_on_organization_id"
  end

  create_table "scheduling_date_overrides", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.time "end_time"
    t.bigint "member_id", null: false
    t.text "reason"
    t.time "start_time"
    t.boolean "unavailable", default: false
    t.datetime "updated_at", null: false
    t.index ["member_id", "date"], name: "index_scheduling_date_overrides_on_member_id_and_date"
    t.index ["member_id"], name: "index_scheduling_date_overrides_on_member_id"
  end

  create_table "scheduling_event_types", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "allow_cancellation", default: true
    t.boolean "allow_rescheduling", default: true
    t.integer "buffer_after_minutes", default: 0
    t.integer "buffer_before_minutes", default: 0
    t.integer "cancellation_policy_hours", default: 24
    t.string "color", default: "#3b82f6"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes", null: false
    t.text "location_details"
    t.string "location_type", default: "in_person"
    t.integer "maximum_days_in_future", default: 60
    t.bigint "member_id", null: false
    t.jsonb "metadata", default: {}
    t.integer "minimum_notice_hours", default: 0
    t.boolean "payment_required_to_book", default: true
    t.integer "price_cents", default: 0
    t.string "price_currency", default: "PEN"
    t.boolean "requires_payment", default: false
    t.integer "rescheduling_policy_hours", default: 24
    t.integer "slots_per_time_slot", default: 1
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_scheduling_event_types_on_active"
    t.index ["member_id", "slug"], name: "index_scheduling_event_types_on_member_id_and_slug", unique: true
    t.index ["member_id"], name: "index_scheduling_event_types_on_member_id"
  end

  create_table "scheduling_locations", force: :cascade do |t|
    t.boolean "active", default: true
    t.text "address"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "phone"
    t.string "postal_code"
    t.jsonb "settings", default: {}
    t.string "slug", null: false
    t.string "state"
    t.string "timezone", default: "America/Lima", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_scheduling_locations_on_active"
    t.index ["organization_id", "slug"], name: "index_scheduling_locations_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_scheduling_locations_on_organization_id"
  end

  create_table "scheduling_members", force: :cascade do |t|
    t.boolean "accepts_bookings", default: true
    t.boolean "active", default: true
    t.text "avatar_url"
    t.string "booking_slug", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.jsonb "settings", default: {}
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active"], name: "index_scheduling_members_on_active"
    t.index ["booking_slug"], name: "index_scheduling_members_on_booking_slug", unique: true
    t.index ["team_id", "user_id"], name: "index_scheduling_members_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_scheduling_members_on_team_id"
    t.index ["user_id"], name: "index_scheduling_members_on_user_id"
  end

  create_table "scheduling_organizations", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "default_currency", default: "PEN"
    t.string "default_locale", default: "es"
    t.text "description"
    t.text "logo_url"
    t.string "name", null: false
    t.jsonb "settings", default: {}
    t.string "slug", null: false
    t.string "timezone", default: "America/Lima", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_scheduling_organizations_on_active"
    t.index ["slug"], name: "index_scheduling_organizations_on_slug", unique: true
  end

  create_table "scheduling_payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "amount_currency", null: false
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.string "external_transaction_id"
    t.text "failure_reason"
    t.jsonb "metadata", default: {}
    t.datetime "paid_at"
    t.string "payment_method"
    t.string "payment_provider"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["booking_id", "status"], name: "index_scheduling_payments_on_booking_id_and_status"
    t.index ["booking_id"], name: "index_scheduling_payments_on_booking_id"
    t.index ["external_transaction_id"], name: "index_scheduling_payments_on_external_transaction_id"
    t.index ["status"], name: "index_scheduling_payments_on_status"
  end

  create_table "scheduling_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false
    t.bigint "member_id", null: false
    t.string "name", null: false
    t.string "timezone", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id", "is_default"], name: "index_scheduling_schedules_on_member_id_and_is_default"
    t.index ["member_id"], name: "index_scheduling_schedules_on_member_id"
  end

  create_table "scheduling_teams", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "color", default: "#3b82f6"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_scheduling_teams_on_active"
    t.index ["location_id", "slug"], name: "index_scheduling_teams_on_location_id_and_slug", unique: true
    t.index ["location_id"], name: "index_scheduling_teams_on_location_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "scheduling_availabilities", "scheduling_schedules", column: "schedule_id"
  add_foreign_key "scheduling_booking_answers", "scheduling_booking_questions", column: "booking_question_id"
  add_foreign_key "scheduling_booking_answers", "scheduling_bookings", column: "booking_id"
  add_foreign_key "scheduling_booking_changes", "scheduling_bookings", column: "booking_id"
  add_foreign_key "scheduling_booking_questions", "scheduling_event_types", column: "event_type_id"
  add_foreign_key "scheduling_bookings", "scheduling_bookings", column: "rescheduled_from_id"
  add_foreign_key "scheduling_bookings", "scheduling_clients", column: "client_id"
  add_foreign_key "scheduling_bookings", "scheduling_event_types", column: "event_type_id"
  add_foreign_key "scheduling_bookings", "scheduling_members", column: "member_id"
  add_foreign_key "scheduling_calendar_connections", "scheduling_members", column: "member_id"
  add_foreign_key "scheduling_clients", "scheduling_organizations", column: "organization_id"
  add_foreign_key "scheduling_date_overrides", "scheduling_members", column: "member_id"
  add_foreign_key "scheduling_event_types", "scheduling_members", column: "member_id"
  add_foreign_key "scheduling_locations", "scheduling_organizations", column: "organization_id"
  add_foreign_key "scheduling_members", "scheduling_teams", column: "team_id"
  add_foreign_key "scheduling_members", "users"
  add_foreign_key "scheduling_payments", "scheduling_bookings", column: "booking_id"
  add_foreign_key "scheduling_schedules", "scheduling_members", column: "member_id"
  add_foreign_key "scheduling_teams", "scheduling_locations", column: "location_id"
end
