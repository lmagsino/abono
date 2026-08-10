class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :slug, null: false

      # Primary billing/HR contact at the employer
      t.string :contact_name, null: false
      t.string :contact_email, null: false
      t.string :contact_phone

      # Where disbursements are funded from. The reference is the provider's
      # own identifier for the employer float wallet (PayMongo/Xendit account
      # or wallet id); it is opaque to us.
      t.string :disbursement_provider
      t.string :disbursement_wallet_reference

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :tenants, :slug, unique: true
    add_index :tenants, :disbursement_wallet_reference, unique: true, where: "disbursement_wallet_reference IS NOT NULL"
  end
end
