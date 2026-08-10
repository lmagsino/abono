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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_100400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "advances", force: :cascade do |t|
    t.decimal "amount_approved", precision: 12, scale: 2
    t.decimal "amount_requested", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.datetime "disbursed_at"
    t.bigint "employee_id", null: false
    t.datetime "requested_at", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "requested_at"], name: "index_advances_on_employee_id_and_requested_at"
    t.index ["employee_id", "status"], name: "index_advances_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_advances_on_employee_id"
    t.index ["tenant_id", "status"], name: "index_advances_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_advances_on_tenant_id"
    t.check_constraint "amount_approved IS NULL OR amount_approved >= 0::numeric", name: "advances_amount_approved_non_negative"
    t.check_constraint "amount_requested > 0::numeric", name: "advances_amount_requested_positive"
  end

  create_table "employees", force: :cascade do |t|
    t.decimal "attendance_rate", precision: 5, scale: 4
    t.datetime "attendance_synced_at"
    t.datetime "created_at", null: false
    t.integer "days_absent_last_30", default: 0, null: false
    t.string "email"
    t.string "employment_status", default: "active", null: false
    t.string "external_employee_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "mobile_number"
    t.decimal "monthly_salary", precision: 12, scale: 2, null: false
    t.date "next_payroll_date"
    t.string "payroll_cycle", default: "semi_monthly", null: false
    t.date "start_date", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "email"], name: "index_employees_on_tenant_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["tenant_id", "employment_status"], name: "index_employees_on_tenant_id_and_employment_status"
    t.index ["tenant_id", "external_employee_id"], name: "index_employees_on_tenant_id_and_external_employee_id", unique: true
    t.index ["tenant_id"], name: "index_employees_on_tenant_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.bigint "advance_id"
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.decimal "balance_after", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.string "entry_type", null: false
    t.bigint "tenant_id", null: false
    t.index ["advance_id"], name: "index_ledger_entries_on_advance_id"
    t.index ["employee_id", "created_at"], name: "index_ledger_entries_on_employee_id_and_created_at"
    t.index ["employee_id"], name: "index_ledger_entries_on_employee_id"
    t.index ["tenant_id", "created_at"], name: "index_ledger_entries_on_tenant_id_and_created_at"
    t.index ["tenant_id", "entry_type"], name: "index_ledger_entries_on_tenant_id_and_entry_type"
    t.index ["tenant_id"], name: "index_ledger_entries_on_tenant_id"
  end

  create_table "repayments", force: :cascade do |t|
    t.bigint "advance_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "deducted_at", null: false
    t.string "payroll_run_reference", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["advance_id", "deducted_at"], name: "index_repayments_on_advance_id_and_deducted_at"
    t.index ["advance_id", "payroll_run_reference"], name: "index_repayments_on_advance_id_and_payroll_run_reference", unique: true
    t.index ["advance_id"], name: "index_repayments_on_advance_id"
    t.index ["tenant_id", "payroll_run_reference"], name: "index_repayments_on_tenant_id_and_payroll_run_reference"
    t.index ["tenant_id"], name: "index_repayments_on_tenant_id"
    t.check_constraint "amount > 0::numeric", name: "repayments_amount_positive"
  end

  create_table "tenants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "contact_email", null: false
    t.string "contact_name", null: false
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "disbursement_provider"
    t.string "disbursement_wallet_reference"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["disbursement_wallet_reference"], name: "index_tenants_on_disbursement_wallet_reference", unique: true, where: "(disbursement_wallet_reference IS NOT NULL)"
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end

  add_foreign_key "advances", "employees"
  add_foreign_key "advances", "tenants"
  add_foreign_key "employees", "tenants"
  add_foreign_key "ledger_entries", "advances"
  add_foreign_key "ledger_entries", "employees"
  add_foreign_key "ledger_entries", "tenants"
  add_foreign_key "repayments", "advances"
  add_foreign_key "repayments", "tenants"
end
