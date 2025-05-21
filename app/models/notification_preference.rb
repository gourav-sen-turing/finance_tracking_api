class NotificationPreference < ApplicationRecord
  belongs_to :user
  belongs_to :notification_type

  validates :user_id, uniqueness: { scope: :notification_type_id }

  # Default all notification types to enabled for a user
  def self.create_defaults_for(user)
    NotificationType.all.each do |notification_type|
      user.notification_preferences.find_or_create_by(notification_type: notification_type) do |pref|
        # Set default thresholds based on notification type
        case notification_type.code
        when NotificationType::BUDGET_ALERT
          pref.threshold_value = 80
          pref.threshold_unit = 'percent'
        when NotificationType::RECURRING_TRANSACTION_UPCOMING
          pref.threshold_value = 3
          pref.threshold_unit = 'days'
        when NotificationType::GOAL_MILESTONE
          pref.threshold_value = 25
          pref.threshold_unit = 'percent'
        end
      end
    end
  end
end
