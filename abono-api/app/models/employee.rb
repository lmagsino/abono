class Employee < ApplicationRecord
  acts_as_tenant :tenant

  has_many :advances, dependent: :destroy
  has_many :ledger_entries, dependent: :destroy
  has_many :repayments, through: :advances

  EMPLOYMENT_STATUSES = %w[active suspended terminated].freeze
  PAYROLL_CYCLES = %w[weekly semi_monthly monthly].freeze

  enum :employment_status, EMPLOYMENT_STATUSES.index_by(&:itself), validate: true
  enum :payroll_cycle, PAYROLL_CYCLES.index_by(&:itself), prefix: :paid, validate: true

  validates :external_employee_id, presence: true
  validates_uniqueness_to_tenant :external_employee_id
  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates_uniqueness_to_tenant :email, allow_nil: true, case_sensitive: false
  validates :start_date, presence: true
  validates :monthly_salary, presence: true, numericality: { greater_than: 0 }
  validates :attendance_rate,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
    allow_nil: true
  validates :days_absent_last_30,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def full_name
    "#{first_name} #{last_name}"
  end
end
