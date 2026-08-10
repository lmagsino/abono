ActsAsTenant.configure do |config|
  # Left permissive while the API surface is still being built (Phase 2/3):
  # console sessions, migrations and seeds all query without a current tenant.
  # Flip to true once controllers set the tenant on every request, so that an
  # unscoped query raises instead of silently reading across tenants.
  config.require_tenant = false
end
