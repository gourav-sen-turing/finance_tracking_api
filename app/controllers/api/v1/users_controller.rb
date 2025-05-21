module Api
  module V1
    class ReportsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/reports/monthly_summary
      def monthly_summary
        year = params[:year].present? ? params[:year].to_i : Time.current.year
        month = params[:month].present? ? params[:month].to_i : Time.current.month

        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month

        # Get transactions for specified month
        transactions = current_user.financial_transactions
                                  .where(date: start_date..end_date)

        # Filter by category if specified
        transactions = transactions.where(category_id: params[:category_id]) if params[:category_id].present?

        # Basic summary statistics
        summary = {
          year: year,
          month: month,
          month_name: Date::MONTHNAMES[month],
          total_income: transactions.income.sum(:amount),
          total_expenses: transactions.expense.sum(:amount).abs,
          transaction_count: transactions.count
        }

        # Calculate net savings and savings rate
        summary[:net_savings] = summary[:total_income] - summary[:total_expenses]
        summary[:savings_rate] = summary[:total_income] > 0 ?
                                 (summary[:net_savings] / summary[:total_income] * 100).round(2) : 0

        # Get spending breakdown by category
        category_breakdown = []
        current_user.categories.each do |category|
          category_transactions = transactions.where(category_id: category.id, transaction_type: 'expense')
          amount = category_transactions.sum(:amount).abs

          if amount > 0
            # Get previous month data for comparison
            previous_month = start_date - 1.month
            previous_month_amount = current_user.financial_transactions
                              .where(date: previous_month.beginning_of_month..previous_month.end_of_month)
                              .where(category_id: category.id, transaction_type: 'expense')
                              .sum(:amount).abs

            # Get budget data if available
            budget = current_user.budgets.find_by(category_id: category.id,
                                                  year: year,
                                                  month: month)

            category_data = {
              id: category.id,
              name: category.name,
              color: category.color,
              amount: amount,
              percentage: summary[:total_expenses] > 0 ?
                         (amount / summary[:total_expenses] * 100).round(2) : 0,
              transaction_count: category_transactions.count,
              comparison_to_previous: {
                difference: amount - previous_month_amount,
                percentage_change: previous_month_amount > 0 ?
                                 ((amount - previous_month_amount) / previous_month_amount * 100).round(2) : 0
              }
            }

            # Add budget info if available
            if budget
              category_data[:budget] = {
                amount: budget.amount,
                remaining: budget.amount - amount,
                usage_percentage: (amount / budget.amount * 100).round(2)
              }
            end

            category_breakdown << category_data
          end
        end

        # Monthly comparison data
        previous_month = start_date - 1.month
        previous_month_expenses = current_user.financial_transactions
                        .where(date: previous_month.beginning_of_month..previous_month.end_of_month)
                        .expense.sum(:amount).abs

        last_year_month = Date.new(year-1, month, 1)
        last_year_expenses = current_user.financial_transactions
                      .where(date: last_year_month.beginning_of_month..last_year_month.end_of_month)
                      .expense.sum(:amount).abs

        comparison = {
          previous_month: {
            total_expenses: previous_month_expenses,
            difference: summary[:total_expenses] - previous_month_expenses,
            percentage_change: previous_month_expenses > 0 ?
                            ((summary[:total_expenses] - previous_month_expenses) / previous_month_expenses * 100).round(2) : 0
          },
          same_month_last_year: {
            total_expenses: last_year_expenses,
            difference: summary[:total_expenses] - last_year_expenses,
            percentage_change: last_year_expenses > 0 ?
                            ((summary[:total_expenses] - last_year_expenses) / last_year_expenses * 100).round(2) : 0
          }
        }

        # Daily spending distribution
        daily_spending = []
        (1..end_date.day).each do |day|
          date = Date.new(year, month, day)
          amount = transactions.where(date: date, transaction_type: 'expense')
                              .sum(:amount).abs
          daily_spending << { day: day, amount: amount }
        end

        response = {
          summary: summary,
          category_breakdown: category_breakdown,
          comparison: comparison,
          daily_spending: daily_spending
        }

        # Include transactions if requested
        if params[:include_transactions] == 'true'
          response[:transactions] = transactions
                                    .order(date: :desc)
                                    .limit(20) # Consider pagination here
        end

        render json: response
      end

      # GET /api/v1/reports/monthly_summary/current
      def current_month
        params[:year] = Time.current.year
        params[:month] = Time.current.month
        monthly_summary
      end

      # GET /api/v1/reports/monthly_summary/:year/:month
      def specific_month
        params[:year] = params[:year]
        params[:month] = params[:month]
        monthly_summary
      end
    end
  end
end
