class BudgetSerializer < BaseSerializer
  # Attributes to be serialized
  attributes :id, :amount, :start_date, :end_date, :created_at, :updated_at

  # Add relationship definitions
  belongs_to :user
  belongs_to :category, if: Proc.new { |record| record.category.present? }

  # Format amount as currency
  attribute :formatted_amount do |budget|
    "$#{sprintf('%.2f', budget.amount)}"
  end

  # Calculate remaining budget
  attribute :remaining do |budget, params|
    if params[:calculate_remaining]
      spent = budget.calculate_spent
      remaining = budget.amount - spent
      {
        amount: remaining,
        formatted: "$#{sprintf('%.2f', remaining)}",
        percentage: ((remaining / budget.amount) * 100).round(2)
      }
    end
  end
end
