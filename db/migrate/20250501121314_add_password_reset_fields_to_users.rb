class AddPasswordResetFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # Add an index to make token lookups faster
    add_index :users, :reset_password_token, unique: true
  end
end
