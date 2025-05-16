class Category < ApplicationRecord
  belongs_to :user
  has_many :financial_transactions, dependent: :nullify
  has_many :budgets, dependent: :destroy

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i, message: "must be a valid hex color code" }, allow_blank: true

  # Default color if none specified
  before_create :set_default_color

  # Get total amount spent in this category
  def total_spent(start_date = nil, end_date = nil)
    scope = financial_transactions.where(transaction_type: 'expense')
    scope = scope.where(date: start_date..end_date) if start_date && end_date
    scope.sum(:amount).abs
  end

  # Get total income in this category
  def total_income(start_date = nil, end_date = nil)
    scope = financial_transactions.where(transaction_type: 'income')
    scope = scope.where(date: start_date..end_date) if start_date && end_date
    scope.sum(:amount)
  end

  private

  def set_default_color
    self.color ||= "##{SecureRandom.hex(3)}" # Random color if none provided
  end
end
