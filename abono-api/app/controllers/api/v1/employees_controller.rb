module Api
  module V1
    class EmployeesController < BaseController
      def index
        scope = Employee.order(:last_name, :first_name)
        scope = scope.where(employment_status: params[:employment_status]) if params[:employment_status].present?

        employees = paginate(scope).to_a
        balances = LedgerService.balances_for(employees)

        render json: {
          data: employees.map { |employee| ApiSerializer.employee(employee, balance: balances[employee.id]) },
          meta: pagination_meta(scope)
        }
      end

      def show
        employee = Employee.find(params[:id])

        render json: {
          data: ApiSerializer.employee(employee, balance: LedgerService.balance_for(employee)),
          advances: employee.advances.order(requested_at: :desc).map { |a| ApiSerializer.advance(a) }
        }
      end
    end
  end
end
