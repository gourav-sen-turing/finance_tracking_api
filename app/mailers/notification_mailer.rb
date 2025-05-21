class NotificationMailer < ApplicationMailer
  def notification_email(notification)
    @notification = notification
    @user = notification.user
    @url = "#{ENV['FRONTEND_URL']}/notifications/#{notification.id}"

    mail(
      to: @user.email,
      subject: notification.title
    )
  end

  def monthly_summary_email(notification)
    @notification = notification
    @user = notification.user
    @metadata = notification.metadata
    @month = Date.parse(@metadata['month'] + '-01').strftime('%B %Y')

    mail(
      to: @user.email,
      subject: "Your #{@month} Financial Summary"
    )
  end
end
