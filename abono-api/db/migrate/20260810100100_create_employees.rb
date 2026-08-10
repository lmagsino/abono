class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :tenant, null: false, foreign_key: true

      # The employer's own id for this person, from their HRIS/payroll export.
      # Unique per tenant so repeated CSV imports reconcile instead of duplicate.
      t.string :external_employee_id, null: false

      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :mobile_number

      t.date :start_date, null: false
      t.string :employment_status, null: false, default: "active"

      # Payroll cycle info — drives when a repayment deduction can be expected.
      t.string :payroll_cycle, null: false, default: "semi_monthly"
      t.decimal :monthly_salary, precision: 12, scale: 2, null: false
      t.date :next_payroll_date

      # Attendance data, refreshed from the employer's attendance system.
      # attendance_rate is a 0..1 fraction over the trailing window.
      t.decimal :attendance_rate, precision: 5, scale: 4
      t.integer :days_absent_last_30, null: false, default: 0
      t.datetime :attendance_synced_at

      t.timestamps
    end

    add_index :employees, [ :tenant_id, :external_employee_id ], unique: true
    add_index :employees, [ :tenant_id, :email ], unique: true, where: "email IS NOT NULL"
    add_index :employees, [ :tenant_id, :employment_status ]
  end
end
