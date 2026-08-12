# Local development data: two employers with a roster each, and enough advance
# history to exercise every status and both ledger directions.
#
# Idempotent. Tenants and employees are looked up by their natural keys, and an
# employee's advance history is only built the first time they are seeded — the
# ledger is append-only, so re-running must not stack duplicate entries onto an
# existing balance.
#
#   bin/rails db:seed

TENANTS = [
  {
    name: "Bayanihan Foods Corporation",
    slug: "bayanihan-foods",
    contact_name: "Maria Santos",
    contact_email: "maria.santos@bayanihanfoods.ph",
    contact_phone: "+63 917 555 0142",
    disbursement_provider: "paymongo",
    disbursement_wallet_reference: "wlt_test_bayanihan_001",
    # Deliberately stricter than the defaults, so the two tenants exercise
    # different policy against the same engine.
    min_tenure_months: 6,
    min_attendance_rate: 0.90,
    max_advances_per_cycle: 1,
    max_outstanding_percentage: 0.40
  },
  {
    name: "Sampaguita BPO Services Inc.",
    slug: "sampaguita-bpo",
    contact_name: "Ramon Dela Cruz",
    contact_email: "ramon.delacruz@sampaguitabpo.ph",
    contact_phone: "+63 918 555 0277",
    disbursement_provider: "xendit",
    disbursement_wallet_reference: "wlt_test_sampaguita_001"
    # Left on the schema defaults: 3 months, 85%, 2 per cycle, 50% cap.
  }
].freeze

# :history drives what gets built for the employee. Each entry is
# [status, amount_requested, amount_approved, months_ago].
EMPLOYEES = {
  "bayanihan-foods" => [
    {
      external_employee_id: "BF-1001", first_name: "Andrea", last_name: "Reyes",
      email: "andrea.reyes@bayanihanfoods.ph", mobile_number: "+63 917 555 1001",
      start_date: 3.years.ago.to_date, monthly_salary: 32_000, payroll_cycle: "semi_monthly",
      attendance_rate: 0.98, days_absent_last_30: 0,
      history: [
        [ "repaid", 5_000, 5_000, 3 ],
        [ "disbursed", 6_000, 6_000, 1 ]
      ]
    },
    {
      external_employee_id: "BF-1002", first_name: "Joshua", last_name: "Mendoza",
      email: "joshua.mendoza@bayanihanfoods.ph", mobile_number: "+63 917 555 1002",
      start_date: 14.months.ago.to_date, monthly_salary: 24_500, payroll_cycle: "semi_monthly",
      attendance_rate: 0.94, days_absent_last_30: 1,
      history: [ [ "disbursed", 4_000, 3_500, 1 ] ]
    },
    {
      external_employee_id: "BF-1003", first_name: "Kristine", last_name: "Bautista",
      email: "kristine.bautista@bayanihanfoods.ph", mobile_number: "+63 917 555 1003",
      start_date: 5.months.ago.to_date, monthly_salary: 19_000, payroll_cycle: "semi_monthly",
      attendance_rate: 0.88, days_absent_last_30: 3,
      # Short tenure and weak attendance — the case Phase 3 should decline.
      history: [ [ "rejected", 8_000, 0, 1 ] ]
    },
    {
      external_employee_id: "BF-1004", first_name: "Miguel", last_name: "Villanueva",
      email: "miguel.villanueva@bayanihanfoods.ph", mobile_number: "+63 917 555 1004",
      start_date: 6.years.ago.to_date, monthly_salary: 45_000, payroll_cycle: "monthly",
      attendance_rate: 1.0, days_absent_last_30: 0,
      history: [ [ "pending", 10_000, nil, 0 ] ]
    },
    {
      external_employee_id: "BF-1005", first_name: "Liza", last_name: "Aquino",
      email: "liza.aquino@bayanihanfoods.ph", mobile_number: "+63 917 555 1005",
      start_date: 2.years.ago.to_date, monthly_salary: 27_500, payroll_cycle: "semi_monthly",
      attendance_rate: 0.96, days_absent_last_30: 1,
      history: []
    },
    {
      external_employee_id: "BF-0912", first_name: "Ferdinand", last_name: "Lim",
      email: "ferdinand.lim@bayanihanfoods.ph", mobile_number: "+63 917 555 0912",
      start_date: 4.years.ago.to_date, monthly_salary: 30_000, payroll_cycle: "semi_monthly",
      employment_status: "terminated", attendance_rate: 0.71, days_absent_last_30: 12,
      history: [ [ "repaid", 3_000, 3_000, 8 ] ]
    }
  ],
  "sampaguita-bpo" => [
    {
      external_employee_id: "SB-2001", first_name: "Patricia", last_name: "Gonzales",
      email: "patricia.gonzales@sampaguitabpo.ph", mobile_number: "+63 918 555 2001",
      start_date: 20.months.ago.to_date, monthly_salary: 38_000, payroll_cycle: "monthly",
      attendance_rate: 0.99, days_absent_last_30: 0,
      history: [
        [ "repaid", 7_500, 7_500, 4 ],
        [ "disbursed", 9_000, 9_000, 1 ]
      ]
    },
    {
      external_employee_id: "SB-2002", first_name: "Nathaniel", last_name: "Ocampo",
      email: "nathaniel.ocampo@sampaguitabpo.ph", mobile_number: "+63 918 555 2002",
      start_date: 9.months.ago.to_date, monthly_salary: 26_000, payroll_cycle: "weekly",
      attendance_rate: 0.92, days_absent_last_30: 2,
      history: [ [ "disbursed", 3_000, 3_000, 1 ] ]
    },
    {
      external_employee_id: "SB-2003", first_name: "Charmaine", last_name: "Tolentino",
      email: "charmaine.tolentino@sampaguitabpo.ph", mobile_number: "+63 918 555 2003",
      start_date: 3.years.ago.to_date, monthly_salary: 41_000, payroll_cycle: "monthly",
      employment_status: "suspended", attendance_rate: 0.83, days_absent_last_30: 5,
      history: [ [ "cancelled", 5_000, nil, 2 ] ]
    },
    {
      external_employee_id: "SB-2004", first_name: "Rodel", last_name: "Pascual",
      email: "rodel.pascual@sampaguitabpo.ph", mobile_number: "+63 918 555 2004",
      start_date: 7.years.ago.to_date, monthly_salary: 52_000, payroll_cycle: "monthly",
      attendance_rate: 0.97, days_absent_last_30: 0,
      # Provider rejected the transfer — the Phase 4 webhook path.
      history: [ [ "failed", 12_000, 12_000, 1 ] ]
    },
    {
      external_employee_id: "SB-2005", first_name: "Jasmine", last_name: "Navarro",
      email: "jasmine.navarro@sampaguitabpo.ph", mobile_number: "+63 918 555 2005",
      start_date: 11.months.ago.to_date, monthly_salary: 29_000, payroll_cycle: "weekly",
      attendance_rate: 0.95, days_absent_last_30: 1,
      history: [ [ "approved", 4_500, 4_000, 0 ] ]
    }
  ]
}.freeze

# Next payday, given a cycle. Rough but plausible: PH semi-monthly payroll
# typically lands on the 15th and the end of the month.
def next_payroll_date_for(cycle, today = Date.current)
  case cycle
  when "weekly"       then today.next_occurring(:friday)
  when "monthly"      then today.end_of_month
  when "semi_monthly" then today.day < 15 ? today.change(day: 15) : today.end_of_month
  end
end

# Builds one advance plus the ledger entries and repayments its status implies.
# balance carries the employee's running outstanding total across advances,
# because balance_after is a per-employee running figure.
def seed_advance!(employee, status, requested, approved, months_ago, balance)
  requested_at = months_ago.zero? ? 2.days.ago : months_ago.months.ago
  disbursed = %w[disbursed repaid failed].include?(status)

  advance = employee.advances.create!(
    amount_requested: requested,
    amount_approved: approved,
    status: status,
    requested_at: requested_at,
    decided_at: (requested_at + 4.minutes unless status == "pending"),
    disbursed_at: (requested_at + 1.hour if disbursed)
  )

  # A failed transfer never moved money, so it leaves no ledger footprint.
  return balance if !disbursed || status == "failed"

  balance += approved
  employee.ledger_entries.create!(
    advance: advance,
    entry_type: "disbursement",
    amount: approved,
    balance_after: balance,
    created_at: advance.disbursed_at
  )

  # A 2% service fee, booked as its own entry so the principal stays legible.
  fee = (approved * 0.02).round(2)
  balance += fee
  employee.ledger_entries.create!(
    advance: advance,
    entry_type: "fee",
    amount: fee,
    balance_after: balance,
    created_at: advance.disbursed_at + 1.second
  )

  if status == "repaid"
    total = approved + fee
    deducted_at = advance.disbursed_at + 2.weeks
    advance.repayments.create!(
      amount: total,
      deducted_at: deducted_at,
      payroll_run_reference: "PR-#{deducted_at.strftime('%Y%m')}-#{deducted_at.day < 16 ? 'A' : 'B'}"
    )

    balance -= total
    employee.ledger_entries.create!(
      advance: advance,
      entry_type: "repayment",
      amount: -total,
      balance_after: balance,
      created_at: deducted_at
    )
  end

  balance
end

ActiveRecord::Base.transaction do
  TENANTS.each do |attrs|
    tenant = Tenant.find_or_initialize_by(slug: attrs[:slug])
    tenant.update!(attrs)

    ActsAsTenant.with_tenant(tenant) do
      EMPLOYEES.fetch(attrs[:slug]).each do |row|
        history = row[:history]
        employee_attrs = row.except(:history)

        employee = Employee.find_or_initialize_by(
          external_employee_id: employee_attrs[:external_employee_id]
        )
        fresh = employee.new_record?
        employee.assign_attributes(employee_attrs)
        employee.next_payroll_date = next_payroll_date_for(employee.payroll_cycle)
        employee.attendance_synced_at = 6.hours.ago
        employee.save!

        # Only build history on first seed — appending to an existing ledger
        # would double-count the balance.
        next unless fresh

        history.reduce(BigDecimal("0")) do |balance, (status, requested, approved, months_ago)|
          seed_advance!(employee, status, requested, approved, months_ago, balance)
        end
      end
    end
  end
end

# Totals across every tenant, which is exactly the kind of query require_tenant
# blocks by default — said out loud here rather than worked around.
ActsAsTenant.without_tenant do
  puts "Seeded #{Tenant.count} tenants, #{Employee.count} employees, " \
       "#{Advance.count} advances, #{LedgerEntry.count} ledger entries, " \
       "#{Repayment.count} repayments."
end

Tenant.order(:name).each do |tenant|
  ActsAsTenant.with_tenant(tenant) do
    outstanding = Employee.includes(:ledger_entries).filter_map do |employee|
      last = employee.ledger_entries.chronological.last
      [ employee.full_name, last.balance_after ] if last && last.balance_after.positive?
    end

    puts "\n#{tenant.name} (#{tenant.slug}) — #{Employee.count} employees, #{Advance.count} advances"
    if outstanding.any?
      outstanding.each { |name, balance| puts "  outstanding: #{name} PHP #{'%.2f' % balance}" }
    else
      puts "  outstanding: none"
    end
  end
end
