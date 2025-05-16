class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category

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

  # Ensure category type matches the transaction type
  def category_type_matches_transaction_type
    if category && category.category_type != transaction_type
      errors.add(:category, "type must match transaction type (#{transaction_type})")
    end
  end
end
