module Reports
  class MonthlySummaryService < BaseReportService
    def generate
      {
        period: {
          start_date: start_date,
          end_date: end_date,
          label: format_period_label
        },
        summary: calculate_summary_stats,
        category_breakdown: calculate_category_breakdown,
        daily_spending: calculate_daily_spending,
        recent_transactions: fetch_recent_transactions
      }
    end

    private

    def calculate_summary_stats
      total_income = income_transactions.sum(:amount)
      total_expenses = expense_transactions.sum(:amount).abs
      net_income = total_income - total_expenses
      savings_rate = calculate_percentage(net_income, total_income)

      # Get data for previous period for comparison
      previous_start, previous_end = calculate_previous_period
      previous_transactions = user.financial_transactions.where(date: previous_start..previous_end)
      previous_income = previous_transactions.income.sum(:amount)
      previous_expenses = previous_transactions.expense.sum(:amount).abs
      previous_net = previous_income - previous_expenses

      # Calculate percentage changes
      income_change = calculate_change_percentage(total_income, previous_income)
      expense_change = calculate_change_percentage(total_expenses, previous_expenses)
      net_change = calculate_change_percentage(net_income, previous_net)

      {
        income: total_income,
        expenses: total_expenses,
        net_income: net_income,
        savings_rate: savings_rate,
        income_change: income_change,
        expense_change: expense_change,
        net_change: net_change,
        transaction_count: financial_transactions.count
      }
    end

    def calculate_category_breakdown
      # Efficiently aggregate expenses by category with a single query
      category_totals = expense_transactions
        .joins(:category)
        .group('categories.id', 'categories.name', 'categories.color')
        .sum(:amount)
        .map do |(category_id, category_name, category_color), amount|
          {
            id: category_id,
            name: category_name,
            color: category_color,
            amount: amount.abs, # Ensure positive value for UI
            percentage: calculate_percentage(amount.abs, expense_transactions.sum(:amount).abs)
          }
        end
        .sort_by { |c| -c[:amount] }

      category_totals
    end

    def calculate_daily_spending
      # Aggregate daily spending data with a single query
      daily_data = financial_transactions
        .group(:date, :transaction_type)
        .order(:date)
        .sum(:amount)

      # Convert to the desired format
      result = []
      (start_date..end_date).each do |date|
        income = (daily_data[[date, 'income']] || 0).to_f
        expense = (daily_data[[date, 'expense']] || 0).to_f.abs

        result << {
          date: date,
          income: income,
          expense: expense,
          net: income - expense
        }
      end

      result
    end

    def fetch_recent_transactions
      financial_transactions
        .includes(:category) # Prevent N+1 query
        .order(date: :desc)
        .limit(5)
        .as_json(include: { category: { only: [:id, :name, :color] } })
    end

    def calculate_previous_period
      # Calculate the previous period based on the current range
      days_in_period = (end_date - start_date).to_i + 1

      [
        start_date - days_in_period.days,
        end_date - days_in_period.days
      ]
    end

    def format_period_label
      if start_date.beginning_of_month == start_date && end_date.end_of_month == end_date
        # Month period
        start_date.strftime("%B %Y")
      else
        # Custom date range
        "#{start_date.strftime('%b %-d')} - #{end_date.strftime('%b %-d, %Y')}"
      end
    end
  end
end
