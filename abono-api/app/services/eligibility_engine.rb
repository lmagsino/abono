# Decides whether an employee may take an advance, and says exactly why.
#
# Deterministic and side-effect free: same employee, same amount, same policy,
# same answer, and nothing is written. Callers persist the outcome; this only
# computes it.
#
# Every rule runs even after one has already failed, so a declined employee
# learns everything blocking them rather than discovering the next problem on
# their next attempt.
#
# The result is codes plus numbers, never prose. Phase 6 hands the structured
# decision to an LLM to phrase for the employee; if this class started
# generating sentences, that copy would end up baked into decisions that are
# also an audit record.
#
#   decision = EligibilityEngine.new(employee: employee, amount: 5_000).call
#   decision.approved?      # => false
#   decision.failure_codes  # => [:minimum_tenure, :attendance]
#   decision.to_h           # => structured payload, LLM- and API-ready
class EligibilityEngine
  # Statuses that consumed a decision this cycle and so count toward the
  # frequency limit. Rejected and cancelled requests never became an advance;
  # a failed transfer moved no money and should not cost the employee a slot.
  FREQUENCY_STATUSES = %w[pending approved disbursed repaid].freeze

  Reason = Data.define(:code, :passed, :detail) do
    def failed? = !passed
    def to_h = { code: code, passed: passed, detail: detail }
  end

  Decision = Data.define(
    :employee_id, :external_employee_id, :tenant_id, :requested_amount,
    :approved, :outstanding_balance, :advance_cap, :available_amount,
    :service_fee, :reasons, :evaluated_at
  ) do
    def approved? = approved
    def declined? = !approved
    def failed_reasons = reasons.select(&:failed?)
    def failure_codes = failed_reasons.map(&:code)

    # Flat, JSON-safe, no prose — the payload Phase 6 phrases and the API
    # returns. Decimals are strings so no float rounding reaches the client.
    def to_h
      {
        employee_id: employee_id,
        external_employee_id: external_employee_id,
        tenant_id: tenant_id,
        requested_amount: requested_amount.to_s("F"),
        approved: approved,
        outstanding_balance: outstanding_balance.to_s("F"),
        advance_cap: advance_cap.to_s("F"),
        available_amount: available_amount.to_s("F"),
        service_fee: service_fee.to_s("F"),
        failure_codes: failure_codes,
        reasons: reasons.map(&:to_h),
        evaluated_at: evaluated_at.iso8601
      }
    end
  end

  def initialize(employee:, amount:, as_of: Date.current)
    @employee = employee
    @tenant = employee.tenant
    @amount = to_decimal(amount)
    @as_of = as_of
  end

  # Runs inside the employee's own tenant rather than inheriting whatever the
  # caller happened to have set, so the frequency count cannot be widened or
  # narrowed by ambient context. Matches LedgerService, which does the same.
  def call
    ActsAsTenant.with_tenant(tenant) { evaluate }
  end

  private

  def evaluate
    outstanding = LedgerService.balance_for(employee)
    cap = advance_cap
    available = [ cap - outstanding, BigDecimal("0") ].max

    reasons = [
      valid_amount_reason,
      employment_reason,
      tenure_reason,
      attendance_reason,
      frequency_reason,
      balance_reason(outstanding, cap, available)
    ]

    Decision.new(
      employee_id: employee.id,
      external_employee_id: employee.external_employee_id,
      tenant_id: tenant.id,
      requested_amount: amount,
      approved: reasons.all?(&:passed),
      outstanding_balance: outstanding,
      advance_cap: cap,
      available_amount: available,
      service_fee: (amount * tenant.service_fee_percentage).round(2),
      reasons: reasons,
      evaluated_at: Time.current
    )
  end

  attr_reader :employee, :tenant, :amount, :as_of

  def valid_amount_reason
    Reason.new(
      code: :valid_amount,
      passed: amount.positive?,
      detail: { requested: amount.to_s("F") }
    )
  end

  def employment_reason
    Reason.new(
      code: :employment_status,
      passed: employee.employment_status == "active",
      detail: { status: employee.employment_status }
    )
  end

  def tenure_reason
    months = tenure_months
    Reason.new(
      code: :minimum_tenure,
      passed: months >= tenant.min_tenure_months,
      detail: {
        tenure_months: months,
        required_months: tenant.min_tenure_months,
        start_date: employee.start_date.iso8601
      }
    )
  end

  # Two independent signals: the trailing rate, and recent absences. A long
  # good history can hold the rate up while someone is currently absent a lot,
  # so the absence count is checked on its own rather than averaged away.
  #
  # Missing attendance data fails closed. Treating "we don't know" as "fine"
  # would approve on the strength of a broken import.
  def attendance_reason
    rate = employee.attendance_rate
    absences = employee.days_absent_last_30

    passed = rate.present? &&
      rate >= tenant.min_attendance_rate &&
      absences <= tenant.max_absences_per_month

    Reason.new(
      code: :attendance,
      passed: passed,
      detail: {
        attendance_rate: rate&.to_s("F"),
        required_rate: tenant.min_attendance_rate.to_s("F"),
        days_absent_last_30: absences,
        max_absences: tenant.max_absences_per_month,
        data_missing: rate.nil?,
        synced_at: employee.attendance_synced_at&.iso8601
      }
    )
  end

  def frequency_reason
    cycle = current_cycle
    used = employee.advances
      .where(status: FREQUENCY_STATUSES)
      .where(requested_at: cycle.first.beginning_of_day..cycle.last.end_of_day)
      .count

    Reason.new(
      code: :request_frequency,
      passed: used < tenant.max_advances_per_cycle,
      detail: {
        advances_this_cycle: used,
        max_per_cycle: tenant.max_advances_per_cycle,
        payroll_cycle: employee.payroll_cycle,
        cycle_start: cycle.first.iso8601,
        cycle_end: cycle.last.iso8601
      }
    )
  end

  def balance_reason(outstanding, cap, available)
    Reason.new(
      code: :outstanding_balance,
      passed: (outstanding + amount) <= cap,
      detail: {
        outstanding_balance: outstanding.to_s("F"),
        requested: amount.to_s("F"),
        projected_balance: (outstanding + amount).to_s("F"),
        advance_cap: cap.to_s("F"),
        available_amount: available.to_s("F"),
        cap_percentage: tenant.max_outstanding_percentage.to_s("F"),
        monthly_salary: employee.monthly_salary.to_s("F")
      }
    )
  end

  # NOTE: the cap is a fraction of gross monthly salary. The intent is net pay,
  # but deductions (SSS, PhilHealth, Pag-IBIG, withholding) are not modelled
  # yet, so this runs slightly generous — a 50% cap on gross is roughly 60% of
  # net. Tighten the percentage or model net pay before going live.
  def advance_cap
    (employee.monthly_salary * tenant.max_outstanding_percentage).round(2)
  end

  # Whole months elapsed, not days/30 — an employee who started on the 20th
  # reaches three months on the 20th, which is how tenure is read in practice.
  def tenure_months
    start = employee.start_date
    months = (as_of.year - start.year) * 12 + (as_of.month - start.month)
    months -= 1 if as_of.day < start.day
    [ months, 0 ].max
  end

  # The pay period the request falls in, which is what the frequency limit is
  # counted against. Philippine semi-monthly payroll runs 1st–15th and
  # 16th–end of month.
  def current_cycle
    case employee.payroll_cycle
    when "weekly"
      as_of.beginning_of_week..as_of.end_of_week
    when "monthly"
      as_of.beginning_of_month..as_of.end_of_month
    when "semi_monthly"
      if as_of.day <= 15
        as_of.change(day: 1)..as_of.change(day: 15)
      else
        as_of.change(day: 16)..as_of.end_of_month
      end
    else
      raise ArgumentError, "unknown payroll cycle #{employee.payroll_cycle.inspect}"
    end
  end

  def to_decimal(value)
    case value
    when BigDecimal then value
    when Integer, Float, String then BigDecimal(value.to_s)
    else raise ArgumentError, "cannot treat #{value.inspect} as an amount"
    end
  end
end
