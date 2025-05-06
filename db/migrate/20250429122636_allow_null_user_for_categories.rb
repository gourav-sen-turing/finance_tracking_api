class AllowNullUserForCategories < ActiveRecord::Migration[7.2]
  def change
    change_column_null :categories, :user_id, true
  end
end
