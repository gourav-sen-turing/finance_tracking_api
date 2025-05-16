class CreateBudgets < ActiveRecord::Migration[7.2]
  def change
    create_table :budgets do |t|
      t.string :name
      t.decimal :amount
      t.date :start_date
      t.date :end_date
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :recurrence
      t.integer :notification_threshold
      t.text :notes
      t.boolean :is_active

      t.timestamps
    end
  end
end
