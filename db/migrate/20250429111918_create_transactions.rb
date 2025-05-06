class CreateTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :transactions do |t|
      t.decimal :amount
      t.string :description
      t.date :transaction_date
      t.string :transaction_type
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :payment_method
      t.string :status
      t.text :notes
      t.string :receipt_image

      t.timestamps
    end
  end
end
