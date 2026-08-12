ActsAsTenant.configure do |config|
  # A scoped query with no current tenant now raises instead of silently
  # reading across employers. This is the difference between a missing scope
  # being a caught error and being a data leak, and it is only safe to turn on
  # because Api::V1::BaseController establishes the tenant before any action.
  #
  # Code that legitimately works across tenants — seeds, rake tasks, console
  # sessions, the ledger integrity sweep — says so explicitly with
  # ActsAsTenant.without_tenant { }. Being made to name that intent is the
  # point: cross-tenant access should be visible in the code that does it.
  config.require_tenant = true
end
