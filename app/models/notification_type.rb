class NotificationType < ApplicationRecord
  has_many :notification_preferences, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # System-defined notification types
  BUDGET_ALERT = 'budget_alert'
  GOAL_MILESTONE = 'goal_milestone'
  RECURRING_TRANSACTION_UPCOMING = 'recurring_transaction_upcoming'
  RECURRING_TRANSACTION_PROCESSED = 'recurring_transaction_processed'
  GOAL_COMPLETED = 'goal_completed'
  UNUSUAL_ACTIVITY = 'unusual_activity'
  MONTHLY_SUMMARY = 'monthly_summary'

  # Helper method to seed default notification types
  def self.seed_defaults
    [
      { code: BUDGET_ALERT, name: 'Budget Alert', description: 'When you approach or exceed budget limits', category: 'budget', icon: 'warning' },
      { code: GOAL_MILESTONE, name: 'Goal Milestone', description: 'When you reach a milestone toward a financial goal', category: 'goal', icon: 'stars' },
      { code: GOAL_COMPLETED, name: 'Goal Completed', description: 'When you complete a financial goal', category: 'goal', icon: 'trophy' },
      { code: RECURRING_TRANSACTION_UPCOMING, name: 'Upcoming Recurring Transaction', description: 'Reminder before a recurring transaction is due', category: 'transaction', icon: 'calendar' },
      { code: RECURRING_TRANSACTION_PROCESSED, name: 'Recurring Transaction Processed', description: 'When a recurring transaction is automatically recorded', category: 'transaction', icon: 'receipt' },
      { code: UNUSUAL_ACTIVITY, name: 'Unusual Account Activity', description: 'When unusual spending patterns are detected', category: 'security', icon: 'security' },
      { code: MONTHLY_SUMMARY, name: 'Monthly Summary', description: 'Monthly summary of your financial activity', category: 'report', icon: 'pie_chart' }
    ].each do |attrs|
      NotificationType.find_or_create_by(code: attrs[:code]) do |nt|
        nt.assign_attributes(attrs)
      end
    end
  end
end
