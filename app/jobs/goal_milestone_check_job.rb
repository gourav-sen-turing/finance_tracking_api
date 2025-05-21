class GoalMilestoneCheckJob < ApplicationJob
  queue_as :scheduled

  def perform
    NotificationService.check_goal_milestones
  end
end
