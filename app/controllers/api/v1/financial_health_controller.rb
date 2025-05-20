module Api
  module V1
    class FinancialHealthController < ApplicationController
      include DateRangeReportable
      before_action :authenticate_user!

      # GET /api/v1/financial_health
      def index
        # Calculate all financial health indicators

        # Get user's financial profile
        profile = current_user.financial_profile || create_default_profile

        # Get transactions for the specified period
        transactions = current_user.financial_transactions
                                  .where(date: @start_date..@end_date)

        # Calculate income and expenses
        total_income = transactions.income.sum(:amount)
        total_expenses = transactions.expense.sum(:amount).abs
        avg_monthly_income = calculate_monthly_average(total_income)
        avg_monthly_expenses = calculate_monthly_average(total_expenses)

        # Get debt payments
        debt_payments = transactions.expense
                                   .where(transaction_subtype: Transaction::DEBT_PAYMENT_SUBTYPES)
                                   .sum(:amount).abs
        monthly_debt_payments = calculate_monthly_average(debt_payments)

        # Get essential expenses
        essential_expenses = transactions.expense
                                       .where(is_essential: true)
                                       .sum(:amount).abs
        monthly_essential_expenses = calculate_monthly_average(essential_expenses)

        # Calculate debt-to-income ratio
        debt_to_income = avg_monthly_income > 0 ?
                       (monthly_debt_payments / avg_monthly_income * 100).round(2) : 0

        # Calculate emergency fund coverage
        emergency_fund_coverage = avg_monthly_expenses > 0 ?
                                (profile.liquid_savings / avg_monthly_expenses).round(2) : 0

        # Calculate essential expense ratio
        essential_expense_ratio = avg_monthly_income > 0 ?
                                (monthly_essential_expenses / avg_monthly_income * 100).round(2) : 0

        # Calculate budget variance
        budget_variances = calculate_budget_variances(current_user, @start_date, @end_date)
        overall_budget_variance = calculate_overall_budget_variance(budget_variances)

        # Calculate financial resilience score
        financial_resilience_score = calculate_financial_resilience_score(
          debt_to_income, emergency_fund_coverage, essential_expense_ratio, overall_budget_variance
        )

        # Build response
        response = {
          date_range: @date_range_metadata,
          financial_profile: {
            liquid_savings: profile.liquid_savings,
            total_assets: profile.total_assets,
            total_liabilities: profile.total_liabilities,
            net_worth: profile.net_worth,
            last_updated: profile.updated_at
          },
          income_summary: {
            total_income: total_income,
            average_monthly: avg_monthly_income
          },
          expense_summary: {
            total_expenses: total_expenses,
            average_monthly: avg_monthly_expenses,
            essential_expenses: essential_expenses,
            discretionary_expenses: total_expenses - essential_expenses
          },
          health_indicators: {
            debt_to_income: {
              ratio: debt_to_income,
              status: determine_dti_status(debt_to_income),
              explanation: "This represents the percentage of your monthly income going toward debt payments."
            },
            emergency_fund: {
              months_coverage: emergency_fund_coverage,
              status: determine_emergency_fund_status(emergency_fund_coverage),
              explanation: "This shows how many months your liquid savings would last based on your average expenses."
            },
            essential_expense_ratio: {
              ratio: essential_expense_ratio,
              status: determine_essential_expense_status(essential_expense_ratio),
              explanation: "This shows what percentage of your income is committed to essential expenses."
            },
            budget_adherence: {
              overall_variance: overall_budget_variance,
              status: determine_budget_variance_status(overall_budget_variance.abs),
              explanation: "This shows how closely your spending matches your budgeted amounts."
            },
            financial_resilience_score: {
              score: financial_resilience_score,
              status: determine_resilience_status(financial_resilience_score),
              explanation: "This is an overall score of your financial health based on multiple factors."
            }
          },
          detailed_budget_variance: budget_variances,
          historical_trends: calculate_historical_health_indicators(current_user),
          improvement_recommendations: generate_improvement_recommendations(
            debt_to_income,
            emergency_fund_coverage,
            essential_expense_ratio,
            overall_budget_variance
          )
        }

        render json: response
      end

      private

      def calculate_monthly_average(amount)
        # Convert total amount to monthly average based on date range
        months_in_range = ((@end_date - @start_date).to_i + 1) / 30.44  # Average days per month
        months_in_range = 1 if months_in_range < 1

        (amount / months_in_range).round(2)
      end

      def calculate_budget_variances(user, start_date, end_date)
        # Get all categories with budgets
        budgeted_categories = user.categories.joins(:budgets).distinct

        variances = []

        budgeted_categories.each do |category|
          # Get budgets for this category in the date range
          relevant_budgets = category.budgets
                                    .where('year >= ? AND year <= ?', start_date.year, end_date.year)
                                    .where('(year = ? AND month >= ?) OR (year = ? AND month <= ?) OR (year > ? AND year < ?)',
                                           start_date.year, start_date.month,
                                           end_date.year, end_date.month,
                                           start_date.year, end_date.year)

          # Skip if no budgets for this period
          next if relevant_budgets.empty?

          total_budget = relevant_budgets.sum(:amount)

          # Get actual spending for this category
          actual_spending = user.financial_transactions
                               .expense
                               .where(date: start_date..end_date, category_id: category.id)
                               .sum(:amount).abs

          # Calculate variance
          variance_amount = actual_spending - total_budget
          variance_percentage = total_budget > 0 ? (variance_amount / total_budget * 100).round(2) : 0

          variances << {
            category_id: category.id,
            category_name: category.name,
            budgeted_amount: total_budget,
            actual_amount: actual_spending,
            variance_amount: variance_amount,
            variance_percentage: variance_percentage,
            status: determine_category_variance_status(variance_percentage)
          }
        end

        variances
      end

      def calculate_overall_budget_variance(variances)
        return 0 if variances.empty?

        total_budgeted = variances.sum { |v| v[:budgeted_amount] }
        total_actual = variances.sum { |v| v[:actual_amount] }

        return 0 if total_budgeted == 0

        ((total_actual - total_budgeted) / total_budgeted * 100).round(2)
      end

      def calculate_financial_resilience_score(dti, emergency_coverage, essential_ratio, budget_variance)
        # Convert each metric to a 0-100 score where higher is better

        # DTI score (lower is better: 0% = 100 points, 50+% = 0 points)
        dti_score = [100 - (dti * 2), 0].max

        # Emergency fund score (higher is better: 6+ months = 100 points, 0 months = 0 points)
        ef_score = [emergency_coverage * 100 / 6, 100].min

        # Essential expenses score (lower is better: 30% = 100 points, 100% = 0 points)
        ee_score = [100 - ((essential_ratio - 30) * 1.43), 0].max

        # Budget variance score (closer to 0 is better: 0% = 100 points, ±25% = 0 points)
        bv_score = [100 - (budget_variance.abs * 4), 0].max

        # Calculate weighted average (weights can be adjusted)
        weighted_score = (
          (dti_score * 0.25) +
          (ef_score * 0.35) +
          (ee_score * 0.25) +
          (bv_score * 0.15)
        ).round(0)

        # Ensure score is within 0-100 range
        [weighted_score, 100].min
      end

      def determine_dti_status(ratio)
        case
        when ratio <= 15
          "excellent"
        when ratio <= 35
          "good"
        when ratio <= 42
          "concerning"
        else
          "critical"
        end
      end

      def determine_emergency_fund_status(months)
        case
        when months >= 6
          "excellent"
        when months >= 3
          "good"
        when months >= 1
          "needs_improvement"
        else
          "critical"
        end
      end

      def determine_essential_expense_status(ratio)
        case
        when ratio < 50
          "excellent"
        when ratio <= 65
          "good"
        when ratio <= 80
          "limited"
        else
          "constrained"
        end
      end

      def determine_budget_variance_status(variance_pct)
        case
        when variance_pct <= 5
          "excellent"
        when variance_pct <= 15
          "good"
        when variance_pct <= 25
          "needs_improvement"
        else
          "poor"
        end
      end

      def determine_category_variance_status(variance_pct)
        if variance_pct < 0
          # Under budget (good)
          variance_pct = variance_pct.abs
          case
          when variance_pct <= 5
            "on_target"
          when variance_pct <= 15
            "under_budget"
          when variance_pct <= 25
            "significantly_under"
          else
            "substantially_under"
          end
        else
          # Over budget (concerning)
          case
          when variance_pct <= 5
            "on_target"
          when variance_pct <= 15
            "over_budget"
          when variance_pct <= 25
            "significantly_over"
          else
            "substantially_over"
          end
        end
      end

      def determine_resilience_status(score)
        case
        when score >= 80
          "excellent"
        when score >= 60
          "good"
        when score >= 40
          "fair"
        when score >= 20
          "needs_attention"
        else
          "critical"
        end
      end

      def calculate_historical_health_indicators(user)
        # Calculate indicators for previous periods for trend analysis
        # Implementation details depend on how much historical data to include

        # Example: Calculate for last 6 months
        result = []

        6.times do |i|
          month_end = Date.current.beginning_of_month - i.months
          month_start = month_end.beginning_of_month

          # Calculate metrics for this month
          # Abbreviated for brevity - would use similar calculations as above
          monthly_metrics = {
            period: month_end.strftime("%b %Y"),
            debt_to_income: calculate_dti_for_period(user, month_start, month_end),
            emergency_fund_coverage: calculate_ef_for_period(user, month_start, month_end),
            essential_expense_ratio: calculate_ee_for_period(user, month_start, month_end),
            financial_resilience_score: calculate_frs_for_period(user, month_start, month_end)
          }

          result << monthly_metrics
        end

        result.reverse  # Return in chronological order
      end

      def generate_improvement_recommendations(dti, emergency_coverage, essential_ratio, budget_variance)
        recommendations = []

        # DTI recommendations
        if dti > 35
          recommendations << {
            indicator: "debt_to_income",
            severity: dti > 42 ? "high" : "medium",
            message: "Your debt-to-income ratio of #{dti}% is higher than recommended. Consider focusing on debt reduction.",
            actions: [
              "Prioritize paying off high-interest debt first",
              "Consider debt consolidation to lower interest rates",
              "Avoid taking on additional debt"
            ]
          }
        end

        # Emergency fund recommendations
        if emergency_coverage < 3
          recommendations << {
            indicator: "emergency_fund",
            severity: emergency_coverage < 1 ? "high" : "medium",
            message: "Your emergency fund would cover expenses for #{emergency_coverage.round(1)} months, which is below the recommended 3-6 months.",
            actions: [
              "Aim to save at least 3-6 months of expenses",
              "Set up automatic transfers to your emergency fund",
              "Consider a separate high-yield savings account for emergencies"
            ]
          }
        end

        # Essential expenses recommendations
        if essential_ratio > 65
          recommendations << {
            indicator: "essential_expense_ratio",
            severity: essential_ratio > 80 ? "high" : "medium",
            message: "Your essential expenses consume #{essential_ratio}% of your income, leaving limited flexibility.",
            actions: [
              "Review essential expenses for potential reductions",
              "Look for more affordable housing options if rent/mortgage is high",
              "Shop around for better rates on insurance and utilities",
              "Focus on increasing income sources"
            ]
          }
        end

        # Budget variance recommendations
        if budget_variance.abs > 15
          direction = budget_variance > 0 ? "over" : "under"
          recommendations << {
            indicator: "budget_variance",
            severity: budget_variance.abs > 25 ? "high" : "medium",
            message: "Your spending is #{budget_variance.abs}% #{direction} budget, indicating room for improved budget management.",
            actions: [
              "Review your budget categories for realistic allocations",
              "Track expenses more regularly",
              "Use the category breakdown to identify problem areas",
              "Consider using the envelope budgeting method"
            ]
          }
        end

        # Return empty array if no recommendations needed
        recommendations
      end

      def create_default_profile
        FinancialProfile.create(
          user: current_user,
          liquid_savings: 0,
          total_assets: 0,
          total_liabilities: 0,
          monthly_debt_payments: 0
        )
      end

      # Abbreviated implementations for historical calculations
      def calculate_dti_for_period(user, start_date, end_date)
        # Implementation details
        rand(5..45)  # Placeholder for illustration
      end

      def calculate_ef_for_period(user, start_date, end_date)
        # Implementation details
        rand(0..8)  # Placeholder for illustration
      end

      def calculate_ee_for_period(user, start_date, end_date)
        # Implementation details
        rand(40..85)  # Placeholder for illustration
      end

      def calculate_frs_for_period(user, start_date, end_date)
        # Implementation details
        rand(30..90)  # Placeholder for illustration
      end
    end
  end
end
