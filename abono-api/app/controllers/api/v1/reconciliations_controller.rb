module Api
  module V1
    # Posts a payroll run's deductions against outstanding advances.
    #
    # Responds 200 even when rows are flagged. Flagged deductions are the
    # expected output of a reconciliation, not a failure of the request — the
    # caller is being handed a review queue, and returning an error status
    # would push HR clients toward retrying a run that partially succeeded.
    # Read `flagged_count` to decide whether a human is needed.
    class ReconciliationsController < BaseController
      MAX_DEDUCTIONS = 5_000

      def create
        deductions = params.require(:deductions)
        reference = params.require(:payroll_run_reference)

        if deductions.size > MAX_DEDUCTIONS
          return render_error(
            status: :payload_too_large,
            code: "too_many_deductions",
            message: "A run may carry at most #{MAX_DEDUCTIONS} deductions; got #{deductions.size}. Split the export."
          )
        end

        result = RepaymentReconciliationService.new(
          tenant: current_tenant_record,
          payroll_run_reference: reference,
          deductions: normalize(deductions)
        ).call

        render json: { data: result.to_h }
      end

      private

      # Deductions arrive as untyped JSON. Only the four keys the service reads
      # are passed through, symbolized — anything else in the payload is
      # ignored rather than trusted.
      def normalize(deductions)
        deductions.map do |deduction|
          permitted = deduction.permit(:employee_id, :external_employee_id, :amount, :deducted_at)
          {
            employee_id: permitted[:employee_id],
            external_employee_id: permitted[:external_employee_id],
            amount: permitted[:amount],
            deducted_at: permitted[:deducted_at]
          }
        end
      end
    end
  end
end
