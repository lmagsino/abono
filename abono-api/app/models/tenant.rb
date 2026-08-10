# An employer. Every other record in the system belongs to exactly one tenant,
# and acts_as_tenant scopes reads and writes to it at the model layer.
class Tenant < ApplicationRecord
  has_many :employees, dependent: :destroy
  has_many :advances, dependent: :destroy
  has_many :ledger_entries, dependent: :destroy
  has_many :repayments, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: {
    with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/,
    message: "must be lowercase letters, numbers and hyphens"
  }
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :disbursement_wallet_reference, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }
end
