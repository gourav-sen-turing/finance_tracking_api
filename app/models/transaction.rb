class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :goal_contributions, dependent: :nullify
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # Callback to process goal contributions
  after_create :process_for_goals
  after_update :update_goal_contributions

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_date, presence: true
  validates :transaction_type, presence: true, inclusion: { in: ['income', 'expense'] }
  validate :category_type_matches_transaction_type

  DEBT_PAYMENT_SUBTYPES = ['mortgage_payment', 'loan_payment', 'credit_card_payment']
  ESSENTIAL_SUBTYPES = ['rent', 'mortgage_payment', 'utilities', 'groceries', 'healthcare', 'insurance']

  # Scopes
  scope :incomes, -> { where(transaction_type: 'income') }
  scope :expenses, -> { where(transaction_type: 'expense') }
  scope :by_date_range, ->(start_date, end_date) { where('transaction_date BETWEEN ? AND ?', start_date, end_date) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  def self.total_income(user_id, start_date = nil, end_date = nil)
    transactions = where(user_id: user_id, transaction_type: 'income')
    transactions = transactions.by_date_range(start_date, end_date) if start_date && end_date
    transactions.sum(:amount)
  end

  def self.balance(user_id, start_date = nil, end_date = nil)
    total_income(user_id, start_date, end_date) - total_expense(user_id, start_date, end_date)
  end

  private
  def process_for_goals
    # Process this transaction for all active goals
    user.financial_goals.active.each do |goal|
      goal.process_transaction(self)
    end
  end

  def update_goal_contributions
    # If transaction amount changed, update related goal contributions
    if saved_change_to_amount?
      original_amount, new_amount = amount_before_last_save, amount
      ratio = new_amount / original_amount

      goal_contributions.each do |contribution|
        # Adjust contribution proportionally
        adjusted_amount = (contribution.amount * ratio).round(2)
        contribution.update(amount: adjusted_amount)
      end
    end
  end

  # Ensure category type matches the transaction type
  def category_type_matches_transaction_type
    if category && category.category_type != transaction_type
      errors.add(:category, "type must match transaction type (#{transaction_type})")
    end
  end
end
