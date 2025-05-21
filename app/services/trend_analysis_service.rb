module Reports
  class TrendAnalysisService < BaseReportService
    def generate
      {
        period: {
          start_date: start_date,
          end_date: end_date,
          months: calculate_months_in_range
        },
        trends: {
          income: calculate_income_trend,
          expense: calculate_expense_trend,
          savings: calculate_savings_trend,
          categories: calculate_category_trends,
          monthly_totals: calculate_monthly_totals
        }
      }
    end

    private

    def calculate_months_in_range
      ((end_date.year * 12 + end_date.month) - (start_date.year * 12 + start_date.month)) + 1
    end

    def calculate_income_trend
      # Get monthly income data
      monthly_income = get_monthly_data('income')

      # Calculate statistics
      values = monthly_income.map { |m| m[:amount] }

      {
        monthly_data: monthly_income,
        average: values.sum / values.length.to_f,
        min: values.min,
        max: values.max,
        trend_direction: calculate_trend_direction(values)
      }
    end

    def calculate_expense_trend
      # Get monthly expense data
      monthly_expenses = get_monthly_data('expense')

      # Calculate statistics
      values = monthly_expenses.map { |m| m[:amount] }

      {
        monthly_data: monthly_expenses,
        average: values.sum / values.length.to_f,
        min: values.min,
        max: values.max,
        trend_direction: calculate_trend_direction(values)
      }
    end

    def calculate_savings_trend
      # Get monthly income and expense data
      monthly_income = get_monthly_data('income')
      monthly_expenses = get_monthly_data('expense')

      # Calculate monthly savings
      months = {}

      monthly_income.each do |income|
        months[income[:month]] = { income: income[:amount] }
      end

      monthly_expenses.each do |expense|
        months[expense[:month]] ||= {}
        months[expense[:month]][:expense] = expense[:amount]
      end

      # Format as an array with savings calculated
      monthly_savings = months.map do |month, data|
        income = data[:income] || 0
        expense = data[:expense] || 0
        savings = income - expense

        {
          month: month,
          income: income,
          expense: expense,
          savings: savings,
          savings_rate: income > 0 ? (savings / income * 100).round(2) : 0
        }
      end.sort_by { |item| Date.parse(item[:month]) }

      # Calculate statistics
      values = monthly_savings.map { |m| m[:savings] }
      rates = monthly_savings.map { |m| m[:savings_rate] }

      {
        monthly_data: monthly_savings,
        average_savings: values.sum / values.length.to_f,
        average_rate: rates.sum / rates.length.to_f,
        min_savings: values.min,
        max_savings: values.max,
        trend_direction: calculate_trend_direction(values)
      }
    end

    def calculate_category_trends
      # Get top categories by total amount
      top_categories = expense_transactions
        .joins(:category)
        .group('categories.id', 'categories.name')
        .order('SUM(amount) DESC')
        .limit(5)
        .pluck('categories.id', 'categories.name')

      # Get monthly data for each category
      category_trends = top_categories.map do |id, name|
        monthly_data = get_monthly_category_data(id)
        values = monthly_data.map { |m| m[:amount] }

        {
          category_id: id,
          category_name: name,
          monthly_data: monthly_data,
          average: values.sum / values.length.to_f,
          trend_direction: calculate_trend_direction(values)
        }
      end

      category_trends
    end

    def calculate_monthly_totals
      # Get first day of each month in the range
      months = []
      current = Date.new(start_date.year, start_date.month, 1)
      end_month = Date.new(end_date.year, end_date.month, 1)

      while current <= end_month
        months << current
        current = current.next_month
      end

      # For each month, get the income, expense, and net
      monthly_totals = months.map do |month|
        month_start = month
        month_end = month.end_of_month

        month_transactions = user.financial_transactions.where(date: month_start..month_end)

        income = month_transactions.income.sum(:amount)
        expenses = month_transactions.expense.sum(:amount).abs

        {
          month: month.strftime('%Y-%m'),
          label: month.strftime('%b %Y'),
          income: income,
          expenses: expenses,
          net: income - expenses
        }
      end

      monthly_totals
    end

    def get_monthly_data(transaction_type)
      # Get first day of each month in the range
      months = []
      current = Date.new(start_date.year, start_date.month, 1)
      end_month = Date.new(end_date.year, end_date.month, 1)

      while current <= end_month
        months << current
        current = current.next_month
      end

      # For each month, get the total for the transaction type
      monthly_data = months.map do |month|
        month_start = month
        month_end = month.end_of_month

        # Get transactions for this month and type
        amount = user.financial_transactions
          .where(date: month_start..month_end, transaction_type: transaction_type)
          .sum(:amount)

        # For expenses, convert to positive amount for display
        amount = amount.abs if transaction_type == 'expense'

        {
          month: month.strftime('%Y-%m'),
          label: month.strftime('%b %Y'),
          amount: amount
        }
      end

      monthly_data
    end

    def get_monthly_category_data(category_id)
      # Get first day of each month in the range
      months = []
      current = Date.new(start_date.year, start_date.month, 1)
      end_month = Date.new(end_date.year, end_date.month, 1)

      while current <= end_month
        months << current
        current = current.next_month
      end

      # For each month, get the total for the category
      monthly_data = months.map do |month|
        month_start = month
        month_end = month.end_of_month

        # Get transactions for this month and category
        amount = user.financial_transactions
          .where(date: month_start..month_end, category_id: category_id)
          .where(transaction_type: 'expense')
          .sum(:amount).abs

        {
          month: month.strftime('%Y-%m'),
          label: month.strftime('%b %Y'),
          amount: amount
        }
      end

      monthly_data
    end

    def calculate_trend_direction(values)
      return 'neutral' if values.length < 2

      # Simple linear regression to determine trend
      x_values = (0...values.length).to_a
      y_values = values

      n = values.length
      sum_x = x_values.sum
      sum_y = y_values.sum
      sum_xx = x_values.map { |x| x * x }.sum
      sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum

      slope = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x).to_f

      if slope > 0.05
        'increasing'
      elsif slope < -0.05
        'decreasing'
      else
        'neutral'
      end
    end
  end
end
