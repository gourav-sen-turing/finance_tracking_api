class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.date :date_of_birth
      t.string :phone
      t.string :currency_preference
      t.string :time_zone

      t.timestamps
    end
  end
end
