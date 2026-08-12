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

  # Advance policy. EligibilityEngine reads these; nothing else should.
  validates :min_tenure_months, :max_absences_per_month, :max_advances_per_cycle,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_attendance_rate, :service_fee_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :max_outstanding_percentage,
    numericality: { greater_than: 0, less_than_or_equal_to: 1 }

  scope :active, -> { where(active: true) }

  KEY_PREFIX = "abono_sk_"

  # Looks up a tenant by plaintext API key. Returns nil for anything unknown or
  # inactive — a deactivated employer's key stops working immediately rather
  # than at the next key rotation.
  def self.authenticate_by_api_key(key)
    return nil if key.blank?

    active.find_by(api_key_digest: digest_api_key(key))
  end

  def self.digest_api_key(key)
    Digest::SHA256.hexdigest(key)
  end

  # Returns the plaintext key. This is the only time it exists in readable
  # form — only the digest is persisted, so a lost key is regenerated, never
  # recovered.
  def regenerate_api_key!
    key = "#{KEY_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    update!(api_key_digest: self.class.digest_api_key(key), api_key_generated_at: Time.current)
    key
  end

  def api_key?
    api_key_digest.present?
  end
end
