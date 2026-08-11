# Sole writer to the ledger.
#
# Every balance in the system is a fold over ledger_entries — nothing is cached
# on employees or advances, so there is no denormalised figure that can drift.
# Past entries are never touched: a correction is a new entry, not an edit.
#
# Sign convention: a positive amount increases what the employee owes
# (disbursement, fee), a negative amount reduces it (repayment, write-off).
#
# All writes go through #append!, which takes a row lock on the employee. Two
# concurrent disbursements for the same person would otherwise read the same
# balance and write the same balance_after, leaving a ledger that no longer
# folds to the truth.
class LedgerService
  class Error < StandardError; end

  # Raised rather than writing a second disbursement for one advance. Silently
  # double-posting is the worst available outcome: it doubles a real debt.
  class AlreadyDisbursedError < Error; end
  class NotDisbursedError < Error; end
  class OverpaymentError < Error; end

  class << self
    # Current outstanding balance for one employee, summed from the ledger.
    def balance_for(employee)
      scoped(employee.tenant) { employee.ledger_entries.sum(:amount) }
    end

    # Outstanding on a single advance: what it put on the books, less what has
    # been paid against it.
    def outstanding_for(advance)
      scoped(advance.tenant) { advance.ledger_entries.sum(:amount) }
    end

    # Books a disbursement (plus the tenant's service fee, if any) and moves the
    # advance to disbursed. Called by the disbursement flow in Phase 4 once the
    # provider confirms the transfer — this method records that money moved, it
    # does not move it.
    def record_disbursement!(advance, at: Time.current)
      amount = advance.amount_approved
      raise Error, "advance ##{advance.id} has no approved amount" if amount.nil?
      raise Error, "advance ##{advance.id} approved amount must be positive" unless amount.positive?

      tenant = advance.tenant
      employee = advance.employee

      scoped(tenant) do
        employee.with_lock do
          if advance.ledger_entries.exists?(entry_type: "disbursement")
            raise AlreadyDisbursedError, "advance ##{advance.id} already has a disbursement entry"
          end

          entries = [ append!(employee:, advance:, entry_type: "disbursement", amount:, at:) ]

          fee = (amount * tenant.service_fee_percentage).round(2)
          if fee.positive?
            # Booked separately so the principal stays legible in the ledger
            # rather than being folded into the disbursed figure.
            entries << append!(employee:, advance:, entry_type: "fee", amount: fee, at: at + 1.second)
          end

          advance.update!(status: "disbursed", disbursed_at: at)
          entries
        end
      end
    end

    # Records a payroll deduction against an advance: the Repayment row and its
    # ledger entry are written together, and the advance is settled if this
    # clears it. RepaymentReconciliationService is the usual caller.
    def record_repayment!(advance:, amount:, deducted_at:, payroll_run_reference:)
      amount = to_decimal(amount)
      raise Error, "repayment amount must be positive" unless amount.positive?

      tenant = advance.tenant
      employee = advance.employee

      scoped(tenant) do
        employee.with_lock do
          unless advance.ledger_entries.exists?(entry_type: "disbursement")
            raise NotDisbursedError, "advance ##{advance.id} has no disbursement to repay"
          end

          outstanding = advance.ledger_entries.sum(:amount)
          if amount > outstanding
            raise OverpaymentError,
              "repayment of #{amount.to_s('F')} exceeds #{outstanding.to_s('F')} outstanding on advance ##{advance.id}"
          end

          repayment = advance.repayments.create!(
            amount: amount,
            deducted_at: deducted_at,
            payroll_run_reference: payroll_run_reference
          )

          entry = append!(
            employee: employee,
            advance: advance,
            entry_type: "repayment",
            amount: -amount,
            at: deducted_at
          )

          # Settled exactly when the ledger says so, not when the arithmetic
          # was expected to work out.
          advance.update!(status: "repaid") if advance.ledger_entries.sum(:amount).zero?

          [ repayment, entry ]
        end
      end
    end

    # Tenant-level position: what the employer's float is currently carrying.
    def tenant_summary(tenant)
      scoped(tenant) do
        per_employee = LedgerEntry.where(tenant: tenant).group(:employee_id).sum(:amount)
        outstanding = per_employee.select { |_id, balance| balance.positive? }

        {
          tenant_id: tenant.id,
          tenant_slug: tenant.slug,
          total_outstanding: outstanding.values.sum || BigDecimal("0"),
          employees_with_balance: outstanding.size,
          employees_total: Employee.where(tenant: tenant).count,
          advances_outstanding: Advance.where(tenant: tenant, status: "disbursed").count,
          largest_balance: outstanding.values.max || BigDecimal("0"),
          as_of: Time.current
        }
      end
    end

    private

    # The only INSERT into ledger_entries. Assumes the caller holds the
    # employee row lock — balance_after is only correct if nothing else can
    # append between the read and the write.
    def append!(employee:, advance:, entry_type:, amount:, at:)
      amount = to_decimal(amount)
      balance_after = employee.ledger_entries.sum(:amount) + amount

      employee.ledger_entries.create!(
        advance: advance,
        entry_type: entry_type,
        amount: amount,
        balance_after: balance_after,
        created_at: at
      )
    end

    # acts_as_tenant fills tenant_id from the current tenant, so every write
    # runs inside the owning tenant rather than relying on the caller to have
    # set one.
    def scoped(tenant, &block)
      ActsAsTenant.with_tenant(tenant, &block)
    end

    def to_decimal(value)
      case value
      when BigDecimal then value
      when Integer, Float, String then BigDecimal(value.to_s)
      else raise Error, "cannot treat #{value.inspect} as an amount"
      end
    end
  end
end
