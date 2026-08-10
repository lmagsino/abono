# Append-only record of every movement in an employee's outstanding balance.
# This table is the source of truth: balances are derived from it, never stored
# on the employee. Rows are inserted and then left alone — the enforcement of
# that (readonly guards, balance recomputation) comes with the ledger logic in
# Phase 3.
class LedgerEntry < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :employee
  belongs_to :advance, optional: true

  ENTRY_TYPES = %w[disbursement repayment fee adjustment].freeze

  enum :entry_type, ENTRY_TYPES.index_by(&:itself), validate: true

  validates :amount, presence: true, numericality: true
  validates :balance_after, presence: true, numericality: true

  scope :chronological, -> { order(:created_at, :id) }
end
