class FinancialProfile < ApplicationRecord
  belongs_to :user

  # Fields:
  # - liquid_savings (decimal)
  # - total_assets (decimal)
  # - total_liabilities (decimal)
  # - monthly_debt_payments (decimal)
  # - financial_goals (jsonb) - optional for advanced features
  # - timestamp fields

  validates :liquid_savings, numericality: { greater_than_or_equal_to: 0 }
  validates :total_assets, numericality: { greater_than_or_equal_to: 0 }
  validates :total_liabilities, numericality: { greater_than_or_equal_to: 0 }
  validates :monthly_debt_payments, numericality: { greater_than_or_equal_to: 0 }

  def net_worth
    total_assets - total_liabilities
  end
end
