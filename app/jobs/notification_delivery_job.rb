class NotificationDeliveryJob < ApplicationJob
  queue_as :notifications

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification

    user = notification.user
    notification_type = notification.notification_type

    # Send email notifications if enabled
    if !notification.email_sent &&
       Notification.should_notify?(user, notification_type.code, :email)

      # Send the email
      NotificationMailer.notification_email(notification).deliver_now

      # Mark as sent
      notification.update(email_sent: true)
    end

    # Send push notifications if enabled
    if !notification.push_sent &&
       Notification.should_notify?(user, notification_type.code, :push)

      # Send push notification
      send_push_notification(notification)

      # Mark as sent
      notification.update(push_sent: true)
    end
  end

  private

  def send_push_notification(notification)
    # Implement push notification logic using your preferred service
    # (Firebase, OneSignal, etc.)

    # Example using a hypothetical PushService
    if defined?(PushService) && notification.user.push_token.present?
      PushService.send_notification(
        token: notification.user.push_token,
        title: notification.title,
        body: notification.content,
        data: {
          notification_id: notification.id,
          notification_type: notification.notification_type.code,
          source_type: notification.source_type,
          source_id: notification.source_id
        }
      )
    end
  end
end
