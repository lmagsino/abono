# A single salary advance request and its lifecycle. Eligibility decisions and
# disbursement live in later phases; this model only holds the record.
class Advance < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :employee

  has_many :repayments, dependent: :destroy
  has_many :ledger_entries, dependent: :restrict_with_error

  STATUSES = %w[pending approved rejected disbursed repaid cancelled failed].freeze

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :amount_requested, presence: true, numericality: { greater_than: 0 }
  validates :amount_approved,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :requested_at, presence: true
end
