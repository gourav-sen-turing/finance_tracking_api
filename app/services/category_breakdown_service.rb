module Reports
  class CategoryBreakdownService < BaseReportService
    def generate
      {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        categories: detailed_category_breakdown,
        total_income: income_transactions.sum(:amount),
        total_expenses: expense_transactions.sum(:amount).abs
      }
    end

    private

    def detailed_category_breakdown
      # Get the main category data with transactions count and amount
      main_query = expense_transactions
        .joins(:category)
        .group('categories.id', 'categories.name', 'categories.color')
        .select(
          'categories.id,
           categories.name,
           categories.color,
           COUNT(financial_transactions.id) AS transaction_count,
           SUM(financial_transactions.amount) AS total_amount'
        )
        .order('total_amount DESC')

      # Calculate totals for percentages
      total_expenses = expense_transactions.sum(:amount).abs

      # Get previous period data for comparison
      previous_start, previous_end = calculate_previous_period
      previous_expenses_by_category = user.financial_transactions
        .where(date: previous_start..previous_end, transaction_type: 'expense')
        .joins(:category)
        .group('categories.id')
        .sum(:amount)
        .transform_values(&:abs)

      # Build comprehensive category data
      categories_data = main_query.map do |category|
        previous_amount = previous_expenses_by_category[category.id] || 0

        # Calculate trend and changes
        change_amount = category.total_amount.abs - previous_amount
        change_percentage = calculate_change_percentage(category.total_amount.abs, previous_amount)

        # Calculate budget status if budgets exist
        budget_info = get_budget_info(category.id)

        {
          id: category.id,
          name: category.name,
          color: category.color,
          transaction_count: category.transaction_count,
          amount: category.total_amount.abs,
          percentage: calculate_percentage(category.total_amount.abs, total_expenses),
          change_amount: change_amount,
          change_percentage: change_percentage,
          budget: budget_info
        }
      end

      categories_data
    end

    def get_budget_info(category_id)
      # Find the budget for this category (if any) in the current period
      budget = user.budgets
        .where(category_id: category_id)
        .where('start_date <= ? AND end_date >= ?', end_date, start_date)
        .first

      return nil unless budget

      # Calculate amount spent in this budget period
      spent_in_period = user.financial_transactions
        .where(category_id: category_id)
        .where(transaction_type: 'expense')
        .where(date: budget.start_date..budget.end_date)
        .sum(:amount)
        .abs

      percentage_used = calculate_percentage(spent_in_period, budget.amount)

      {
        id: budget.id,
        amount: budget.amount,
        start_date: budget.start_date,
        end_date: budget.end_date,
        spent: spent_in_period,
        remaining: [budget.amount - spent_in_period, 0].max,
        percentage_used: percentage_used,
        status: determine_budget_status(percentage_used)
      }
    end

    def determine_budget_status(percentage)
      if percentage < 50
        'safe'
      elsif percentage < 80
        'warning'
      else
        'danger'
      end
    end

    def calculate_previous_period
      # Calculate the previous period of the same length
      days_in_period = (end_date - start_date).to_i + 1

      [
        start_date - days_in_period.days,
        end_date - days_in_period.days
      ]
    end
  end
end
