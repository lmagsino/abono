class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  # Append-only source of truth for employee balances. Rows are never updated
  # or deleted, so there is no updated_at column — created_at is declared by
  # hand rather than via t.timestamps.
  def change
    create_table :ledger_entries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      # Present for disbursement/repayment/fee entries, null for standalone
      # adjustments that are not tied to a single advance.
      t.references :advance, null: true, foreign_key: true

      t.string :entry_type, null: false

      # Signed: positive increases what the employee owes, negative reduces it.
      t.decimal :amount, precision: 12, scale: 2, null: false
      # Running outstanding balance for the employee after this entry.
      t.decimal :balance_after, precision: 12, scale: 2, null: false

      t.datetime :created_at, null: false
    end

    add_index :ledger_entries, [ :employee_id, :created_at ]
    add_index :ledger_entries, [ :tenant_id, :created_at ]
    add_index :ledger_entries, [ :tenant_id, :entry_type ]
  end
end
