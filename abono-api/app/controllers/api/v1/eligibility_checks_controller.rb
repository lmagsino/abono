module Api
  module V1
    # A dry run of the eligibility rules. Writes nothing.
    #
    # Exists so the employee app can show what someone qualifies for before
    # they commit to asking. Without it the only way to find out would be to
    # submit a real request and have a decline recorded against you.
    class EligibilityChecksController < BaseController
      def create
        employee = Employee.find(params[:employee_id])
        decision = EligibilityEngine.new(employee: employee, amount: params.require(:amount)).call

        render json: { data: ApiSerializer.decision(decision) }
      rescue ArgumentError => e
        render_error(status: :bad_request, code: "invalid_amount", message: e.message)
      end
    end
  end
end
