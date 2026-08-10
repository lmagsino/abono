class CreateAdvances < ActiveRecord::Migration[8.1]
  def change
    create_table :advances do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true

      t.decimal :amount_requested, precision: 12, scale: 2, null: false
      # Null until a decision is made; 0 is a valid (fully declined) outcome.
      t.decimal :amount_approved, precision: 12, scale: 2

      t.string :status, null: false, default: "pending"

      t.datetime :requested_at, null: false
      t.datetime :decided_at
      t.datetime :disbursed_at

      t.timestamps
    end

    add_index :advances, [ :tenant_id, :status ]
    add_index :advances, [ :employee_id, :status ]
    add_index :advances, [ :employee_id, :requested_at ]

    add_check_constraint :advances, "amount_requested > 0", name: "advances_amount_requested_positive"
    add_check_constraint :advances, "amount_approved IS NULL OR amount_approved >= 0", name: "advances_amount_approved_non_negative"
  end
end
