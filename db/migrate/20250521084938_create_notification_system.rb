class CreateNotificationSystem < ActiveRecord::Migration[7.2]
  def change
    # Store notification types/templates
    create_table :notification_types do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :description
      t.string :icon # For UI representation
      t.string :category # e.g., 'budget', 'goal', 'transaction', 'security'
      t.boolean :system_notification, default: false # true for system-wide notifications

      t.timestamps
    end

    # Store user notification preferences
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification_type, null: false, foreign_key: true
      t.boolean :email_enabled, default: true
      t.boolean :push_enabled, default: true
      t.boolean :in_app_enabled, default: true
      t.integer :threshold_value # For numeric thresholds like "notify when over 90%"
      t.string :threshold_unit # e.g., 'percent', 'days', 'amount'

      t.timestamps

      t.index [:user_id, :notification_type_id], unique: true
    end

    # Store actual notification instances
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification_type, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.string :status, default: 'unread' # unread, read, archived
      t.datetime :read_at
      t.datetime :archived_at

      # Polymorphic association for notification context
      t.references :source, polymorphic: true

      # Delivery status tracking
      t.boolean :email_sent, default: false
      t.boolean :push_sent, default: false

      # Additional data for the notification (JSON)
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index [:user_id, :status]
      t.index :created_at
    end
  end
end
