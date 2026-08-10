class CreateRepayments < ActiveRecord::Migration[8.1]
  def change
    create_table :repayments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :advance, null: false, foreign_key: true

      t.decimal :amount, precision: 12, scale: 2, null: false
      t.datetime :deducted_at, null: false

      # The employer's payroll run this deduction came from. Reconciliation in
      # Phase 3 matches on (tenant, payroll_run_reference).
      t.string :payroll_run_reference, null: false

      t.timestamps
    end

    add_index :repayments, [ :tenant_id, :payroll_run_reference ]
    add_index :repayments, [ :advance_id, :deducted_at ]
    # One deduction per advance per payroll run — guards against double-posting
    # the same payroll export.
    add_index :repayments, [ :advance_id, :payroll_run_reference ], unique: true

    add_check_constraint :repayments, "amount > 0", name: "repayments_amount_positive"
  end
end
