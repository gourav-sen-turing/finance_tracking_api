class RecurringTransactionReminderJob < ApplicationJob
  queue_as :scheduled

  def perform
    NotificationService.check_upcoming_recurring_transactions
  end
end
