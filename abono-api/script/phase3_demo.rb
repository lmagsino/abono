# Walks the three Phase 3 services over the Phase 2 seed data.
#
#   bin/rails runner script/phase3_demo.rb
#
# Everything runs inside a transaction that is rolled back at the end, so the
# script is repeatable and leaves the development database as it found it. The
# writes are real while it runs — the ledger entries and repayments below were
# genuinely inserted, then undone.

def heading(text)
  puts "\n#{'─' * 78}\n#{text}\n#{'─' * 78}"
end

def peso(amount) = "PHP #{'%12s' % ('%.2f' % amount)}"

def show_decision(employee, amount)
  decision = EligibilityEngine.new(employee: employee, amount: amount).call
  verdict = decision.approved? ? "APPROVED" : "DECLINED"

  puts "\n#{employee.full_name} — #{employee.tenant.slug} — requests #{peso(amount)}"
  puts "  #{verdict}#{"  (#{decision.failure_codes.join(', ')})" unless decision.approved?}"
  puts "  outstanding #{peso(decision.outstanding_balance)}   cap #{peso(decision.advance_cap)}   available #{peso(decision.available_amount)}"

  decision.reasons.each do |reason|
    puts "    #{reason.passed ? 'pass' : 'FAIL'}  #{reason.code}"
    next if reason.passed
    reason.detail.each { |key, value| puts "            #{key}: #{value}" }
  end

  decision
end

ActiveRecord::Base.transaction do
  bayanihan = Tenant.find_by!(slug: "bayanihan-foods")
  sampaguita = Tenant.find_by!(slug: "sampaguita-bpo")

  heading "TENANT POLICY — same engine, two configurations"
  [ bayanihan, sampaguita ].each do |tenant|
    puts "#{tenant.slug.ljust(16)} tenure >= #{tenant.min_tenure_months}mo   " \
         "attendance >= #{tenant.min_attendance_rate.to_s('F')}   " \
         "max #{tenant.max_advances_per_cycle}/cycle   " \
         "cap #{(tenant.max_outstanding_percentage * 100).to_i}% of salary   " \
         "fee #{(tenant.service_fee_percentage * 100).to_i}%"
  end

  heading "1. ELIGIBILITY — an approval"
  show_decision(bayanihan.employees.find_by!(external_employee_id: "BF-1002"), 5_000)

  heading "2. ELIGIBILITY — declines, one per rule"
  # Three rules fail at once: short tenure, weak attendance, over the cap.
  show_decision(bayanihan.employees.find_by!(external_employee_id: "BF-1003"), 8_000)
  # Already used this month's single allowed request.
  show_decision(bayanihan.employees.find_by!(external_employee_id: "BF-1004"), 5_000)
  # No longer employed.
  show_decision(bayanihan.employees.find_by!(external_employee_id: "BF-0912"), 2_000)
  # Would fit for a new borrower, but not on top of what is already owed.
  show_decision(bayanihan.employees.find_by!(external_employee_id: "BF-1001"), 12_000)

  heading "3. ELIGIBILITY — the structured payload Phase 6 will phrase"
  decision = EligibilityEngine.new(
    employee: bayanihan.employees.find_by!(external_employee_id: "BF-1003"),
    amount: 8_000
  ).call
  puts JSON.pretty_generate(decision.to_h)

  heading "4. LEDGER — balance is a fold over the entries"
  andrea = bayanihan.employees.find_by!(external_employee_id: "BF-1001")
  puts "#{andrea.full_name} — every entry, oldest first:"
  running = BigDecimal("0")
  andrea.ledger_entries.chronological.each do |entry|
    running += entry.amount
    flag = running == entry.balance_after ? "ok" : "MISMATCH"
    puts "  #{entry.created_at.strftime('%Y-%m-%d')}  #{entry.entry_type.ljust(13)}" \
         "#{peso(entry.amount)}   balance_after #{peso(entry.balance_after)}  [#{flag}]"
  end
  puts "  recomputed from entries: #{peso(running)}"
  puts "  LedgerService.balance_for: #{peso(LedgerService.balance_for(andrea))}"
  puts "\n  per advance:"
  andrea.advances.each do |advance|
    puts "    ##{advance.id} #{advance.status.ljust(10)} outstanding #{peso(LedgerService.outstanding_for(advance))}"
  end

  heading "5. LEDGER — recording a disbursement"
  jasmine = sampaguita.employees.find_by!(external_employee_id: "SB-2005")
  approved = jasmine.advances.find_by!(status: "approved")
  puts "#{jasmine.full_name} — advance ##{approved.id}, approved #{peso(approved.amount_approved)}"
  puts "  balance before: #{peso(LedgerService.balance_for(jasmine))}"
  LedgerService.record_disbursement!(approved).each do |entry|
    puts "  + #{entry.entry_type.ljust(13)} #{peso(entry.amount)}   balance_after #{peso(entry.balance_after)}"
  end
  puts "  balance after:  #{peso(LedgerService.balance_for(jasmine))}"
  puts "  advance status: #{approved.reload.status}, disbursed_at #{approved.disbursed_at}"
  puts "\n  a second disbursement for the same advance is refused:"
  begin
    LedgerService.record_disbursement!(approved)
  rescue LedgerService::AlreadyDisbursedError => e
    puts "    #{e.class.name.split('::').last}: #{e.message}"
  end

  heading "6. LEDGER — tenant-level outstanding"
  [ bayanihan, sampaguita ].each do |tenant|
    summary = LedgerService.tenant_summary(tenant)
    puts "#{summary[:tenant_slug]}"
    puts "  total outstanding      #{peso(summary[:total_outstanding])}"
    puts "  employees with balance #{summary[:employees_with_balance]} of #{summary[:employees_total]}"
    puts "  advances outstanding   #{summary[:advances_outstanding]}"
    puts "  largest single balance  #{peso(summary[:largest_balance])}"
  end

  heading "7. RECONCILIATION — a payroll run with problems in it"
  andrea_outstanding = LedgerService.outstanding_for(andrea.advances.find_by!(status: "disbursed"))
  joshua = bayanihan.employees.find_by!(external_employee_id: "BF-1002")
  liza = bayanihan.employees.find_by!(external_employee_id: "BF-1005")

  deductions = [
    # Exact match — settles the advance.
    { employee_id: andrea.id, amount: andrea_outstanding, deducted_at: Time.current },
    # Partial payment — flagged, not part-applied.
    { employee_id: joshua.id, amount: 2_000, deducted_at: Time.current },
    # Nothing owed.
    { employee_id: liza.id, amount: 1_000, deducted_at: Time.current },
    # Not on this tenant's roster.
    { external_employee_id: "BF-9999", amount: 500, deducted_at: Time.current }
  ]

  puts "run PR-DEMO-01 with #{deductions.size} deductions:"
  deductions.each do |d|
    who = d[:employee_id] || d[:external_employee_id]
    puts "  #{who.to_s.ljust(10)} #{peso(d[:amount])}"
  end

  result = RepaymentReconciliationService.new(
    tenant: bayanihan,
    payroll_run_reference: "PR-DEMO-01",
    deductions: deductions
  ).call

  puts "\nmatched (#{result.matched.size}), total #{peso(result.matched_total)}:"
  result.matched.each do |match|
    puts "  #{match.external_employee_id}  advance ##{match.advance_id}  #{peso(match.amount)}  repayment ##{match.repayment_id}"
  end

  puts "\nflagged for review (#{result.flagged.size}), total #{peso(result.flagged_total)}:"
  result.flagged.each do |flag|
    puts "  #{(flag.external_employee_id || '—').ljust(10)} #{peso(flag.amount)}  #{flag.code}"
    flag.detail.each { |key, value| puts "             #{key}: #{value}" }
  end
  puts "\nclean run? #{result.clean?}"

  settled = andrea.advances.find_by(status: "repaid", id: result.matched.first&.advance_id)
  puts "\nAndrea's matched advance is now #{settled&.status.inspect}, " \
       "outstanding #{peso(LedgerService.outstanding_for(settled))}" if settled
  puts "Andrea's balance: #{peso(LedgerService.balance_for(andrea))}"

  # The advance was cleared to repaid above, so the replay is filtered out
  # before the unique index is reached — it comes back as
  # :no_outstanding_advance rather than :already_reconciled. Either way no
  # second repayment is written, which is the property that matters.
  heading "8. RECONCILIATION — replaying the same run posts nothing twice"
  replay = RepaymentReconciliationService.new(
    tenant: bayanihan,
    payroll_run_reference: "PR-DEMO-01",
    deductions: [ { employee_id: andrea.id, amount: andrea_outstanding, deducted_at: Time.current } ]
  ).call
  replay.flagged.each { |flag| puts "  #{flag.code}: #{flag.detail.inspect}" }
  puts "  matched this time: #{replay.matched.size}"

  heading "LEDGER INTEGRITY — every entry still folds to its balance_after"
  broken = Employee.unscoped.includes(:ledger_entries).reject do |employee|
    running = BigDecimal("0")
    employee.ledger_entries.sort_by { |e| [ e.created_at, e.id ] }
      .all? { |e| running += e.amount; running == e.balance_after }
  end
  puts "employees with an inconsistent ledger: #{broken.size}"

  puts "\n#{'═' * 78}"
  puts "Rolling back — the database is left exactly as the seeds made it."
  puts "#{'═' * 78}"
  raise ActiveRecord::Rollback
end
