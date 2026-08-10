# A payroll deduction applied against an advance. Reconciliation against the
# employer's payroll run is Phase 3.
class Repayment < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :advance

  has_one :employee, through: :advance

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :deducted_at, presence: true
  validates :payroll_run_reference, presence: true, uniqueness: { scope: :advance_id }
end
