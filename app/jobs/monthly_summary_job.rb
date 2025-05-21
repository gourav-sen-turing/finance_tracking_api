class MonthlySummaryJob < ApplicationJob
  queue_as :scheduled

  def perform
    NotificationService.generate_monthly_summaries
  end
end
