# Hand-written serializers rather than a gem: the payloads are small, and this
# keeps one obvious place to check what the API exposes.
#
# Two rules hold throughout.
#
# Money is always a decimal string, never a float. 6120.0 in JSON is a float
# the moment a JavaScript client parses it, and float arithmetic on money is
# how cents go missing.
#
# Nothing here reaches for an association that the caller has not already
# loaded, so a list endpoint cannot silently become N+1 by adding a field.
module ApiSerializer
  module_function

  def money(value)
    return nil if value.nil?

    BigDecimal(value.to_s).to_s("F")
  end

  def employee(employee, balance: nil)
    {
      id: employee.id,
      external_employee_id: employee.external_employee_id,
      first_name: employee.first_name,
      last_name: employee.last_name,
      full_name: employee.full_name,
      email: employee.email,
      mobile_number: employee.mobile_number,
      employment_status: employee.employment_status,
      start_date: employee.start_date.iso8601,
      payroll_cycle: employee.payroll_cycle,
      next_payroll_date: employee.next_payroll_date&.iso8601,
      monthly_salary: money(employee.monthly_salary),
      attendance_rate: employee.attendance_rate&.to_s("F"),
      days_absent_last_30: employee.days_absent_last_30,
      attendance_synced_at: employee.attendance_synced_at&.iso8601,
      outstanding_balance: money(balance)
    }
  end

  def advance(advance)
    {
      id: advance.id,
      employee_id: advance.employee_id,
      status: advance.status,
      amount_requested: money(advance.amount_requested),
      amount_approved: money(advance.amount_approved),
      requested_at: advance.requested_at&.iso8601,
      decided_at: advance.decided_at&.iso8601,
      disbursed_at: advance.disbursed_at&.iso8601,
      decision: advance.decision
    }
  end

  def ledger_entry(entry)
    {
      id: entry.id,
      employee_id: entry.employee_id,
      advance_id: entry.advance_id,
      entry_type: entry.entry_type,
      amount: money(entry.amount),
      balance_after: money(entry.balance_after),
      created_at: entry.created_at.iso8601
    }
  end

  def repayment(repayment)
    {
      id: repayment.id,
      advance_id: repayment.advance_id,
      amount: money(repayment.amount),
      deducted_at: repayment.deducted_at.iso8601,
      payroll_run_reference: repayment.payroll_run_reference
    }
  end

  # The engine already returns an LLM- and API-ready payload. Passing it
  # through unchanged keeps one definition of a decision's shape, so Phase 6
  # phrases exactly what the API returned.
  def decision(decision)
    decision.to_h
  end

  def tenant_summary(summary)
    summary.merge(
      total_outstanding: money(summary[:total_outstanding]),
      largest_balance: money(summary[:largest_balance]),
      as_of: summary[:as_of].iso8601
    )
  end
end
