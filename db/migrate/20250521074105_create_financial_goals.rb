class CreateFinancialGoals < ActiveRecord::Migration[6.1]
  def change
    create_table :financial_goals do |t|
      t.string :title, null: false
      t.text :description
      t.decimal :target_amount, precision: 12, scale: 2, null: false
      t.decimal :starting_amount, precision: 12, scale: 2, default: 0.0
      t.decimal :current_amount, precision: 12, scale: 2, default: 0.0
      t.date :target_date
      t.string :goal_type, null: false # savings, debt_reduction, emergency_fund, investment, custom
      t.string :status, default: 'active' # active, complete, abandoned
      t.references :user, null: false, foreign_key: true

      # Additional fields for tracking
      t.date :completion_date
      t.decimal :contribution_amount, precision: 10, scale: 2 # for regular contributions
      t.string :contribution_frequency # daily, weekly, monthly

      # Auto-detection options
      t.boolean :auto_track, default: true
      t.string :tracking_method, default: 'category' # category, tag, account, manual

      # Track by category, tag, or account
      t.string :tracking_criteria, array: true, default: []

      t.timestamps
    end

    add_index :financial_goals, [:user_id, :goal_type]
    add_index :financial_goals, [:user_id, :status]

    # Create goal_contributions to track transaction-based contributions
    create_table :goal_contributions do |t|
      t.references :financial_goal, null: false, foreign_key: true
      t.references :financial_transaction, foreign_key: true, null: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :contribution_type # transaction, manual, recurring
      t.text :notes

      t.timestamps
    end

    add_index :goal_contributions, [:financial_goal_id, :created_at]

    # Create join table for categories that contribute to goals
    create_table :goal_categories do |t|
      t.references :financial_goal, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.index [:financial_goal_id, :category_id], unique: true
    end

    # Optional: Add tags table for more flexible tracking
    create_table :tags do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tags, [:user_id, :name], unique: true

    # Optional: Add tagging join table
    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: true
      t.references :financial_transaction, null: false, foreign_key: true

      t.index [:tag_id, :financial_transaction_id], unique: true
    end

    # Optional: Add tag relation to goals
    create_table :goal_tags do |t|
      t.references :financial_goal, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.index [:financial_goal_id, :tag_id], unique: true
    end
  end
end
