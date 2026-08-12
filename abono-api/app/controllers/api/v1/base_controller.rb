module Api
  module V1
    # Every API request authenticates as a tenant and runs inside that tenant.
    #
    # set_current_tenant_through_filter is what makes acts_as_tenant's
    # require_tenant setting safe to turn on: with the tenant established
    # before any action runs, a query that somehow escapes scoping raises
    # instead of quietly returning another employer's rows.
    #
    # Errors are rendered from one place in one shape. Handlers are ordered
    # most-general first, because Rails matches rescue_from bottom-up.
    class BaseController < ApplicationController
      include ActsAsTenant::ControllerExtensions

      set_current_tenant_through_filter
      before_action :authenticate_tenant!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from LedgerService::Error, with: :render_conflict

      private

      attr_reader :current_tenant_record

      def authenticate_tenant!
        tenant = Tenant.authenticate_by_api_key(bearer_token)

        if tenant.nil?
          # Deliberately uniform: an unknown key, a malformed header and a
          # deactivated tenant are indistinguishable from outside, so probing
          # cannot tell a caller which tenants exist.
          return render_error(
            status: :unauthorized,
            code: "unauthorized",
            message: "A valid API key is required. Send it as: Authorization: Bearer <key>"
          )
        end

        @current_tenant_record = tenant
        set_current_tenant(tenant)
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        header[/\ABearer (.+)\z/, 1]
      end

      # Pagination that cannot be turned off. An employer with 20,000 employees
      # should not be able to ask for all of them in one request by accident.
      def paginate(scope)
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].to_i
        per_page = 50 if per_page <= 0
        per_page = [ per_page, 200 ].min

        scope.limit(per_page).offset((page - 1) * per_page)
      end

      def pagination_meta(scope)
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].to_i
        per_page = 50 if per_page <= 0
        per_page = [ per_page, 200 ].min
        total = scope.count

        { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
      end

      def render_error(status:, code:, message:, detail: nil)
        payload = { error: { code: code, message: message } }
        payload[:error][:detail] = detail if detail
        render json: payload, status: status
      end

      def render_not_found(exception)
        render_error(
          status: :not_found,
          code: "not_found",
          message: "#{exception.model || 'Record'} not found in this tenant"
        )
      end

      def render_bad_request(exception)
        render_error(status: :bad_request, code: "parameter_missing", message: exception.message)
      end

      def render_unprocessable(exception)
        render_error(
          status: :unprocessable_content,
          code: "validation_failed",
          message: exception.record.errors.full_messages.to_sentence,
          detail: exception.record.errors.to_hash(true)
        )
      end

      # The ledger refused the write — already disbursed, overpayment, nothing
      # to repay. The request was well-formed but conflicts with the current
      # state, which is 409 rather than 422.
      def render_conflict(exception)
        render_error(status: :conflict, code: "ledger_conflict", message: exception.message)
      end
    end
  end
end
