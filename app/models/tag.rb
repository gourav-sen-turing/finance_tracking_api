class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :financial_transactions, through: :taggings
  has_many :goal_tags, dependent: :destroy
  has_many :financial_goals, through: :goal_tags

  validates :name, presence: true, uniqueness: { scope: :user_id }
end
