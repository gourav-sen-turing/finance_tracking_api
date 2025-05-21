class AnalyzeFinancialGoalsJob < ApplicationJob
  queue_as :default

  def perform
    # Update all active goals status
    FinancialGoal.active.find_each do |goal|
      # Check if goal is now complete
      if goal.current_amount >= goal.target_amount
        goal.update(status: 'complete', completion_date: Date.current)

        # Optionally send notification
        NotifyGoalCompleteJob.perform_later(goal.id) if defined?(NotifyGoalCompleteJob)
      end

      # Check for missed target dates
      if goal.target_date.present? && goal.target_date < Date.current
        # Either mark as missed or extend depending on your business logic
        # Here we just log it
        Rails.logger.info "Goal ##{goal.id} missed target date: #{goal.target_date}"

        # Optionally send notification
        NotifyGoalMissedTargetJob.perform_later(goal.id) if defined?(NotifyGoalMissedTargetJob)
      end
    end
  end
end
