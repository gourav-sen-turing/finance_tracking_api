class GoalContribution < ApplicationRecord
  belongs_to :financial_goal
  belongs_to :financial_transaction, optional: true

  validates :amount, presence: true, numericality: true
  validates :contribution_type, inclusion: {
    in: %w[transaction manual recurring]
  }

  # Callback to update goal progress after contribution
  after_create :update_goal_progress
  after_destroy :recalculate_goal_progress

  private

  def update_goal_progress
    financial_goal.update(
      current_amount: financial_goal.current_amount + amount
    )

    # Check if goal is now complete
    if financial_goal.current_amount >= financial_goal.target_amount &&
       financial_goal.status == 'active'
      financial_goal.update(
        status: 'complete',
        completion_date: Date.current
      )
    end
  end

  def recalculate_goal_progress
    financial_goal.recalculate_progress!
  end
end
