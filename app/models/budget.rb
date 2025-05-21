class Budget < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :notifications, as: :source, dependent: :nullify

  # We don't directly associate budgets with transactions
  # Instead, we provide methods to calculate budget usage

  # Validations
  validates :first_name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date
  validate :category_type_is_expense

  # Methods to check budget status
  def transactions_in_period
    user.transactions
        .where(category: category)
        .where(transaction_date: start_date..end_date)
  end

  def spent_amount
    transactions_in_period.sum(:amount)
  end

  def remaining_amount
    amount - spent_amount
  end

  def percentage_used
    (spent_amount / amount * 100).round(2)
  end

  def exceeded?
    spent_amount > amount
  end

  # Calculate percentage spent of budget
  def calculate_spent_percentage
    return 0 if amount.nil? || amount <= 0
    (amount_spent / amount * 100).round(1)
  end

  # Check if this budget has already sent an alert at the given percentage threshold
  def alert_sent_for_threshold?(threshold)
    notifications.joins(:notification_type)
                .where(notification_types: { code: NotificationType::BUDGET_ALERT })
                .where("metadata->>'percentage' = ?", threshold.to_s)
                .exists?
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end

  def category_type_is_expense
    if category && category.category_type != 'expense'
      errors.add(:category, "must be an expense category for budgeting")
    end
  end
end
