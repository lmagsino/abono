# Matches a payroll run's deductions against outstanding advances.
#
# This is the one place where the employer's payroll system and our ledger have
# to agree, and the two will drift: someone edits a deduction by hand, an
# employee leaves mid-cycle, a run gets exported twice. So the guiding rule
# here is that anything ambiguous is flagged for a human, never guessed at.
#
# Matching is exact. A deduction settles an advance only when it equals that
# advance's outstanding balance to the centavo. Partial payments are NOT
# applied — a 2,000 deduction against a 6,120 advance is flagged, not
# part-applied — because the likeliest cause is a payroll error, and guessing
# which advance a partial belongs to would put a wrong number in an append-only
# ledger. See :amount_mismatch below when you decide to support them.
#
# Each deduction is processed in its own transaction. One flagged row must not
# roll back the deductions that did reconcile cleanly.
#
#   result = RepaymentReconciliationService.new(
#     tenant: tenant,
#     payroll_run_reference: "PR-202608-B",
#     deductions: [{ employee_id: 3, amount: 6_120, deducted_at: Date.current }]
#   ).call
#   result.matched  # => [Match]
#   result.flagged  # => [Flag] — needs manual review
class RepaymentReconciliationService
  # Advances that can receive a deduction: money left our float and has not
  # been fully repaid.
  SETTLEABLE_STATUSES = %w[disbursed].freeze

  Match = Data.define(:employee_id, :external_employee_id, :advance_id, :amount, :repayment_id) do
    def to_h
      { employee_id: employee_id, external_employee_id: external_employee_id,
        advance_id: advance_id, amount: amount.to_s("F"), repayment_id: repayment_id }
    end
  end

  # code is why a human is needed; detail carries what we saw, including the
  # candidate advances, so the reviewer does not have to go digging.
  Flag = Data.define(:code, :employee_id, :external_employee_id, :amount, :detail) do
    def to_h
      { code: code, employee_id: employee_id, external_employee_id: external_employee_id,
        amount: amount&.to_s("F"), detail: detail }
    end
  end

  Result = Data.define(:tenant_id, :payroll_run_reference, :matched, :flagged, :run_at) do
    def matched_total = matched.sum(BigDecimal("0"), &:amount)
    def flagged_total = flagged.sum(BigDecimal("0")) { |f| f.amount || BigDecimal("0") }
    def clean? = flagged.empty?

    def to_h
      { tenant_id: tenant_id, payroll_run_reference: payroll_run_reference,
        matched_count: matched.size, flagged_count: flagged.size,
        matched_total: matched_total.to_s("F"), flagged_total: flagged_total.to_s("F"),
        matched: matched.map(&:to_h), flagged: flagged.map(&:to_h),
        run_at: run_at.iso8601 }
    end
  end

  def initialize(tenant:, payroll_run_reference:, deductions:)
    @tenant = tenant
    @payroll_run_reference = payroll_run_reference
    @deductions = deductions
  end

  def call
    matched = []
    flagged = []

    ActsAsTenant.with_tenant(tenant) do
      deductions.each do |deduction|
        outcome = reconcile(deduction)
        outcome.is_a?(Match) ? matched << outcome : flagged << outcome
      end
    end

    Result.new(
      tenant_id: tenant.id,
      payroll_run_reference: payroll_run_reference,
      matched: matched,
      flagged: flagged,
      run_at: Time.current
    )
  end

  private

  attr_reader :tenant, :payroll_run_reference, :deductions

  def reconcile(deduction)
    amount = to_decimal(deduction[:amount])
    employee = find_employee(deduction)

    if employee.nil?
      return flag(:unknown_employee, nil, amount, {
        given_employee_id: deduction[:employee_id],
        given_external_employee_id: deduction[:external_employee_id]
      })
    end

    unless amount&.positive?
      return flag(:invalid_amount, employee, amount, { given: deduction[:amount].inspect })
    end

    candidates = employee.advances.where(status: SETTLEABLE_STATUSES).order(:disbursed_at)
    balances = candidates.to_h { |advance| [ advance, LedgerService.outstanding_for(advance) ] }
    open = balances.select { |_advance, balance| balance.positive? }

    if open.empty?
      return flag(:no_outstanding_advance, employee, amount, {
        employee_balance: LedgerService.balance_for(employee).to_s("F")
      })
    end

    # Oldest exact match wins, so a run that could settle either of two equal
    # advances clears the one that has been outstanding longest.
    advance, = open.find { |_advance, balance| balance == amount }

    if advance.nil?
      return flag(:amount_mismatch, employee, amount, {
        candidates: open.map { |adv, balance|
          { advance_id: adv.id, outstanding: balance.to_s("F"),
            disbursed_at: adv.disbursed_at&.iso8601 }
        },
        employee_balance: LedgerService.balance_for(employee).to_s("F")
      })
    end

    settle(advance, employee, amount, deduction)
  end

  def settle(advance, employee, amount, deduction)
    repayment, = ActiveRecord::Base.transaction do
      LedgerService.record_repayment!(
        advance: advance,
        amount: amount,
        deducted_at: deduction[:deducted_at] || Time.current,
        payroll_run_reference: payroll_run_reference
      )
    end

    Match.new(
      employee_id: employee.id,
      external_employee_id: employee.external_employee_id,
      advance_id: advance.id,
      amount: amount,
      repayment_id: repayment.id
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # The unique index on (advance_id, payroll_run_reference) caught a replay of
    # a run that was already posted. Not an error worth aborting the batch for,
    # but a human should know the export was submitted twice.
    #
    # Currently unreachable: exact-match settling always clears the advance to
    # repaid, so a replay is filtered out by SETTLEABLE_STATUSES before it gets
    # here and comes back as :no_outstanding_advance instead. Kept because it
    # goes live the moment partial payments are supported, and the index is the
    # only thing standing between a duplicated export and a double-paid advance.
    flag(:already_reconciled, employee, amount, { advance_id: advance.id })
  rescue LedgerService::Error => e
    flag(:ledger_rejected, employee, amount, { advance_id: advance.id, error: e.message })
  end

  # Payroll exports usually carry the employer's own identifier, so accept
  # either that or our id.
  def find_employee(deduction)
    if deduction[:employee_id]
      Employee.find_by(id: deduction[:employee_id])
    elsif deduction[:external_employee_id]
      Employee.find_by(external_employee_id: deduction[:external_employee_id])
    end
  end

  def flag(code, employee, amount, detail)
    Flag.new(
      code: code,
      employee_id: employee&.id,
      external_employee_id: employee&.external_employee_id,
      amount: amount,
      detail: detail
    )
  end

  def to_decimal(value)
    case value
    when BigDecimal then value
    when Integer, Float, String then BigDecimal(value.to_s)
    end
  rescue ArgumentError
    nil
  end
end
