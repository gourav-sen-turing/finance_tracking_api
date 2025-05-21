class GoalCategory < ApplicationRecord
  belongs_to :financial_goal
  belongs_to :category

  validates :financial_goal_id, uniqueness: { scope: :category_id }
end
