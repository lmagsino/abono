# The eligibility thresholds are per-employer: a BPO with tight attendance
# tracking and a food manufacturer with seasonal staff will not want the same
# rules. Defaults here are the conservative starting position an employer gets
# before anyone tunes them.
class AddAdvancePolicyToTenants < ActiveRecord::Migration[8.1]
  def change
    change_table :tenants, bulk: true do |t|
      t.integer :min_tenure_months, null: false, default: 3
      t.decimal :min_attendance_rate, precision: 5, scale: 4, null: false, default: 0.85
      t.integer :max_absences_per_month, null: false, default: 5
      t.integer :max_advances_per_cycle, null: false, default: 2
      # Ceiling on total outstanding, as a fraction of monthly pay.
      t.decimal :max_outstanding_percentage, precision: 5, scale: 4, null: false, default: 0.50
      t.decimal :service_fee_percentage, precision: 5, scale: 4, null: false, default: 0.02
    end

    add_check_constraint :tenants, "min_tenure_months >= 0", name: "tenants_min_tenure_non_negative"
    add_check_constraint :tenants, "min_attendance_rate >= 0 AND min_attendance_rate <= 1", name: "tenants_min_attendance_rate_fraction"
    add_check_constraint :tenants, "max_advances_per_cycle >= 0", name: "tenants_max_advances_non_negative"
    add_check_constraint :tenants, "max_outstanding_percentage > 0 AND max_outstanding_percentage <= 1", name: "tenants_max_outstanding_fraction"
    add_check_constraint :tenants, "service_fee_percentage >= 0 AND service_fee_percentage <= 1", name: "tenants_service_fee_fraction"
  end
end
