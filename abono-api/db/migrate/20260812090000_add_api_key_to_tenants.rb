# Per-tenant API key. The plaintext key is shown once at generation and never
# stored — only its SHA-256 digest, which is what incoming requests are looked
# up by.
#
# SHA-256 rather than bcrypt on purpose. bcrypt's cost factor exists to slow
# brute force against low-entropy human passwords; an API key is 256 bits of
# randomness, so there is nothing to brute force. More importantly, bcrypt
# would force a scan-and-compare across every tenant on each request, while a
# digest column is a single indexed lookup.
class AddApiKeyToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :api_key_digest, :string
    add_column :tenants, :api_key_generated_at, :datetime

    add_index :tenants, :api_key_digest, unique: true
  end
end
