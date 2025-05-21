class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notification_type
  belongs_to :source, polymorphic: true, optional: true

  validates :title, presence: true

  # Scopes for filtering
  scope :unread, -> { where(status: 'unread') }
  scope :read, -> { where(status: 'read') }
  scope :archived, -> { where(status: 'archived') }
  scope :recent, -> { where(created_at: 30.days.ago..Time.current) }

  # Mark as read
  def mark_as_read!
    update(status: 'read', read_at: Time.current) if status == 'unread'
  end

  # Archive notification
  def archive!
    update(status: 'archived', archived_at: Time.current)
  end

  # Check if user should be notified (based on preferences)
  def self.should_notify?(user, notification_type_code, channel = :in_app)
    preference = user.notification_preferences
                   .joins(:notification_type)
                   .find_by(notification_types: { code: notification_type_code })

    return true unless preference # Default to notify if no preference set

    case channel
    when :email
      preference.email_enabled
    when :push
      preference.push_enabled
    when :in_app
      preference.in_app_enabled
    else
      true
    end
  end

  # Create a notification with proper checks
  def self.notify(user, notification_type_code, title, content = nil, source = nil, metadata = {})
    notification_type = NotificationType.find_by(code: notification_type_code)
    return false unless notification_type

    # Check if user wants this notification (for in-app)
    return false unless should_notify?(user, notification_type_code, :in_app)

    # Create the notification
    notification = user.notifications.create!(
      notification_type: notification_type,
      title: title,
      content: content,
      source: source,
      metadata: metadata
    )

    # Queue delivery for other channels
    NotificationDeliveryJob.perform_later(notification.id) if
      should_notify?(user, notification_type_code, :email) ||
      should_notify?(user, notification_type_code, :push)

    if notification.persisted?
      NotificationChannel.broadcast_to(
        user,
        {
          id: notification.id,
          title: notification.title,
          content: notification.content,
          notification_type: notification.notification_type.as_json(only: [:code, :name, :icon, :category]),
          created_at: notification.created_at
        }
      )
    end

    notification
  end
end
