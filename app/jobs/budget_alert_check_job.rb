class BudgetAlertCheckJob < ApplicationJob
  queue_as :scheduled

  def perform
    NotificationService.check_budget_alerts
  end
end
