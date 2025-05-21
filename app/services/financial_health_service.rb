module Reports
  class FinancialHealthService < BaseReportService
    def generate
      {
        period: {
          start_date: start_date,
          end_date: end_date
        },
        metrics: calculate_financial_metrics,
        trends: calculate_trends,
        recommendations: generate_recommendations
      }
    end

    private

    def calculate_financial_metrics
      # Calculate current period metrics
      income = income_transactions.sum(:amount)
      expenses = expense_transactions.sum(:amount).abs
      savings = income - expenses
      savings_rate = calculate_percentage(savings, income)

      # Calculate debt-to-income ratio if we have debt data
      monthly_debt_payments = calculate_monthly_debt_payments
      monthly_income = calculate_monthly_income
      debt_to_income_ratio = monthly_income > 0 ? (monthly_debt_payments / monthly_income) * 100 : nil

      # Calculate emergency fund coverage
      monthly_essential_expenses = calculate_monthly_essential_expenses
      emergency_fund_balance = get_emergency_fund_balance
      emergency_fund_months = monthly_essential_expenses > 0 ? (emergency_fund_balance / monthly_essential_expenses).round(1) : nil

      # Calculate expense distribution
      expense_distribution = calculate_expense_distribution

      {
        income: income,
        expenses: expenses,
        savings: savings,
        savings_rate: savings_rate,
        debt_to_income_ratio: debt_to_income_ratio,
        emergency_fund_months: emergency_fund_months,
        expense_distribution: expense_distribution,
        health_score: calculate_financial_health_score(
          savings_rate,
          debt_to_income_ratio,
          emergency_fund_months
        )
      }
    end

    def calculate_trends
      # Get data for last 6 months
      end_month = Date.new(end_date.year, end_date.month, 1)
      start_month = (end_month - 5.months)

      monthly_metrics = []

      (0..5).each do |months_ago|
        current_month = end_month - months_ago.months
        month_start = current_month.beginning_of_month
        month_end = current_month.end_of_month

        # Get transactions for this month
        month_transactions = user.financial_transactions
          .where(date: month_start..month_end)

        # Calculate metrics
        month_income = month_transactions.income.sum(:amount)
        month_expenses = month_transactions.expense.sum(:amount).abs
        month_savings = month_income - month_expenses
        month_savings_rate = calculate_percentage(month_savings, month_income)

        monthly_metrics << {
          month: current_month.strftime('%b %Y'),
          income: month_income,
          expenses: month_expenses,
          savings: month_savings,
          savings_rate: month_savings_rate
        }
      end

      # Reverse so they're in chronological order
      monthly_metrics.reverse
    end

    def generate_recommendations
      recommendations = []

      # Calculate metrics for recommendations
      income = income_transactions.sum(:amount)
      expenses = expense_transactions.sum(:amount).abs
      savings = income - expenses
      savings_rate = calculate_percentage(savings, income)

      # Savings rate recommendations
      if savings_rate < 10
        recommendations << {
          category: 'savings',
          title: 'Increase your savings rate',
          description: 'Aim to save at least 15-20% of your income for long-term financial health.',
          priority: 'high'
        }
      elsif savings_rate < 20
        recommendations << {
          category: 'savings',
          title: 'Good savings habits, but room for improvement',
          description: 'Consider increasing your savings rate to 20% for better long-term financial security.',
          priority: 'medium'
        }
      end

      # Emergency fund recommendations
      emergency_fund_months = get_emergency_fund_balance / calculate_monthly_essential_expenses rescue 0
      if emergency_fund_months < 3
        recommendations << {
          category: 'emergency_fund',
          title: 'Build your emergency fund',
          description: 'Aim for 3-6 months of essential expenses in your emergency fund.',
          priority: 'high'
        }
      elsif emergency_fund_months < 6
        recommendations << {
          category: 'emergency_fund',
          title: 'Continue building your emergency fund',
          description: 'You\'re on the right track. Consider increasing your emergency fund to 6 months of expenses for added security.',
          priority: 'medium'
        }
      end

      # Budget recommendations
      over_budget_categories = find_over_budget_categories
      if over_budget_categories.any?
        categories_list = over_budget_categories.map { |c| c[:name] }.join(', ')
        recommendations << {
          category: 'budget',
          title: 'Over-budget categories detected',
          description: "You're over budget in these categories: #{categories_list}. Review your spending in these areas.",
          priority: 'high'
        }
      end

      # Add more recommendation types as needed

      recommendations
    end

    def calculate_monthly_debt_payments
      # For this example, we'll assume this comes from debt-related categories
      # In a real implementation, you might have specific debt records
      debt_categories = user.categories.where("name ILIKE ?", "%debt%").or(
        user.categories.where("name ILIKE ?", "%loan%")
      ).pluck(:id)

      # Calculate average monthly debt payments from the last 3 months
      three_months_ago = end_date - 3.months

      user.financial_transactions
        .where(category_id: debt_categories)
        .where(transaction_type: 'expense')
        .where(date: three_months_ago..end_date)
        .sum(:amount).abs / 3.0
    end

    def calculate_monthly_income
      # Calculate average monthly income from the last 3 months
      three_months_ago = end_date - 3.months

      user.financial_transactions
        .where(transaction_type: 'income')
        .where(date: three_months_ago..end_date)
        .sum(:amount) / 3.0
    end

    def calculate_monthly_essential_expenses
      # Identify essential expense categories
      essential_categories = user.categories.where("name ILIKE ANY(ARRAY[?])",
        ["%rent%", "%mortgage%", "%grocery%", "%food%", "%utility%", "%insurance%"]
      ).pluck(:id)

      # Calculate average monthly essential expenses from the last 3 months
      three_months_ago = end_date - 3.months

      user.financial_transactions
        .where(category_id: essential_categories)
        .where(transaction_type: 'expense')
        .where(date: three_months_ago..end_date)
        .sum(:amount).abs / 3.0
    end

    def get_emergency_fund_balance
      # For this example, we'll assume the user has a specific account type for emergency funds
      # In a real implementation, you might have a dedicated field or table for this
      emergency_fund_accounts = user.accounts.where("name ILIKE ?", "%emergency%").or(
        user.accounts.where("name ILIKE ?", "%savings%")
      )

      emergency_fund_accounts.sum(:balance)
    end

    def calculate_expense_distribution
      # Get expense distribution by category type
      # First, let's define some category groups (these could be dynamically defined)
      category_groups = {
        essential: ["housing", "utilities", "groceries", "insurance", "healthcare"],
        discretionary: ["dining", "entertainment", "shopping", "travel"],
        savings: ["investments", "savings"],
        debt: ["loan", "credit card", "debt"]
      }

      # Initialize counters
      distribution = {
        essential: 0,
        discretionary: 0,
        savings: 0,
        debt: 0,
        other: 0
      }

      # Get all expense transactions with categories
      expenses_with_categories = expense_transactions
        .joins(:category)
        .select('financial_transactions.amount, categories.name')

      total_expenses = expense_transactions.sum(:amount).abs

      # Categorize each transaction
      expenses_with_categories.each do |transaction|
        category_name = transaction.name.downcase
        amount = transaction.amount.abs

        # Determine which group this falls into
        group = :other

        category_groups.each do |key, terms|
          if terms.any? { |term| category_name.include?(term) }
            group = key
            break
          end
        end

        distribution[group] += amount
      end

      # Convert to percentages
      distribution.transform_values do |amount|
        calculate_percentage(amount, total_expenses)
      end
    end

    def find_over_budget_categories
      # Find categories that are over budget in the current period
      over_budget = []

      # Get active budgets
      user.budgets
        .where('start_date <= ? AND end_date >= ?', end_date, start_date)
        .each do |budget|
          # Calculate amount spent in this budget period
          spent = user.financial_transactions
            .where(category_id: budget.category_id)
            .where(transaction_type: 'expense')
            .where(date: budget.start_date..budget.end_date)
            .sum(:amount).abs

          if spent > budget.amount
            over_budget << {
              id: budget.category_id,
              name: budget.category.name,
              budget_amount: budget.amount,
              actual_amount: spent,
              percentage_over: calculate_percentage(spent - budget.amount, budget.amount)
            }
          end
        end

      over_budget
    end

    def calculate_financial_health_score(savings_rate, debt_to_income_ratio, emergency_fund_months)
      score = 0
      max_score = 0

      # Score based on savings rate (0-40 points)
      if savings_rate.present?
        max_score += 40
        if savings_rate >= 30
          score += 40
        elsif savings_rate >= 20
          score += 30
        elsif savings_rate >= 15
          score += 25
        elsif savings_rate >= 10
          score += 15
        elsif savings_rate >= 5
          score += 10
        elsif savings_rate > 0
          score += 5
        end
      end

      # Score based on debt-to-income ratio (0-30 points)
      if debt_to_income_ratio.present?
        max_score += 30
        if debt_to_income_ratio < 15
          score += 30
        elsif debt_to_income_ratio < 25
          score += 25
        elsif debt_to_income_ratio < 36
          score += 20
        elsif debt_to_income_ratio < 43
          score += 10
        else
          score += 0
        end
      end

      # Score based on emergency fund (0-30 points)
      if emergency_fund_months.present?
        max_score += 30
        if emergency_fund_months >= 6
          score += 30
        elsif emergency_fund_months >= 4
          score += 20
        elsif emergency_fund_months >= 3
          score += 15
        elsif emergency_fund_months >= 1
          score += 5
        else
          score += 0
        end
      end

      # Return health score as a percentage
      max_score > 0 ? (score.to_f / max_score * 100).round : nil
    end
  end
end
