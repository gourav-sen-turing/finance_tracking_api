class CreateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :categories do |t|
      t.string :name
      t.text :description
      t.string :category_type
      t.string :color
      t.string :icon
      t.references :user, null: false, foreign_key: true
      t.boolean :is_default
      t.integer :parent_category_id

      t.timestamps
    end
  end
end
