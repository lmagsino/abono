module Api
  module V1
    # Read-only. The ledger is written by LedgerService, through the
    # disbursement and reconciliation paths — never by a client posting an
    # entry directly, which is why there is no create action here.
    class LedgerController < BaseController
      def show
        employee = Employee.find(params[:employee_id])
        scope = employee.ledger_entries.chronological

        render json: {
          data: paginate(scope).map { |entry| ApiSerializer.ledger_entry(entry) },
          balance: ApiSerializer.money(LedgerService.balance_for(employee)),
          meta: pagination_meta(scope)
        }
      end

      def summary
        render json: { data: ApiSerializer.tenant_summary(LedgerService.tenant_summary(current_tenant_record)) }
      end
    end
  end
end
