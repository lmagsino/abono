module Api
  module V1
    class AdvancesController < BaseController
      def index
        scope = Advance.order(requested_at: :desc)
        scope = scope.where(employee_id: params[:employee_id]) if params[:employee_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?

        render json: {
          data: paginate(scope).map { |advance| ApiSerializer.advance(advance) },
          meta: pagination_meta(scope)
        }
      end

      def show
        advance = Advance.find(params[:id])

        render json: {
          data: ApiSerializer.advance(advance),
          repayments: advance.repayments.order(:deducted_at).map { |r| ApiSerializer.repayment(r) },
          outstanding: ApiSerializer.money(LedgerService.outstanding_for(advance))
        }
      end

      # Submits a real request and records the answer.
      #
      # A decline is persisted, not thrown away: the employee is entitled to see
      # why, and the stored decision is the only record of the policy and data
      # that produced it. Rejected advances are excluded from the frequency
      # limit, so being declined does not cost someone a slot in their cycle.
      #
      # Responds 201 either way. The engine ran and returned an answer, which is
      # a successful request — the caller reads `status` to see which answer.
      # Nothing is disbursed here; money moves in Phase 4.
      def create
        employee = Employee.find(params.require(:employee_id))
        amount = params.require(:amount)
        decision = EligibilityEngine.new(employee: employee, amount: amount).call

        advance = employee.advances.create!(
          amount_requested: decision.requested_amount,
          amount_approved: decision.approved? ? decision.requested_amount : 0,
          status: decision.approved? ? "approved" : "rejected",
          requested_at: Time.current,
          decided_at: Time.current,
          decision: decision.to_h
        )

        render json: {
          data: ApiSerializer.advance(advance),
          decision: ApiSerializer.decision(decision)
        }, status: :created
      rescue ArgumentError => e
        render_error(status: :bad_request, code: "invalid_amount", message: e.message)
      end
    end
  end
end
