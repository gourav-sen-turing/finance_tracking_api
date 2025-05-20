module Api
  module V1
    class ReportsController < ApplicationController
      include DateRangeReportable
      before_action :authenticate_user!
      after_action :set_rate_limit_headers
      after_action :set_pagination_headers, only: [:monthly_summary]

      # GET /api/v1/reports/monthly_summary
      def monthly_summary
        year = params[:year].present? ? params[:year].to_i : Time.current.year
        month = params[:month].present? ? params[:month].to_i : Time.current.month

        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month

        # Get transactions for specified month
        transactions = current_user.financial_transactions
                                  .where(date: @start_date..@end_date)

        # Filter by category if specified
        transactions = transactions.where(category_id: params[:category_id]) if params[:category_id].present?

        @pagy = transactions.page(params[:page] || 1).per(params[:per_page] || 20)

        # Calculate summary metrics
        income = transactions.where(transaction_type: 'income').sum(:amount)
        expenses = transactions.where(transaction_type: 'expense').sum(:amount)

        # Get category breakdown
        category_breakdown = transactions.joins(:category)
                                       .group('categories.name')
                                       .sum(:amount)

        # Format as percentage of total expenses
        total_expenses = expenses.zero? ? 1 : expenses  # Avoid division by zero
        category_percentages = category_breakdown.transform_values do |amount|
          (amount / total_expenses.to_f * 100).round(2)
        end

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
          date_range: @date_range_metadata,
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

        render json: {
          summary: {
            month: month,
            year: year,
            income: income,
            expenses: expenses,
            net: income - expenses,
            savings_rate: income.zero? ? 0 : ((income - expenses) / income * 100).round(2)
          },
          category_breakdown: category_percentages,
          transactions: @pagy,
          meta: {
            total_count: @pagy.total_count,
            total_pages: @pagy.total_pages,
            current_page: @pagy.current_page,
            per_page: @pagy.limit_value
          }
        }
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

      def income_expense_analysis
        # Get date range parameters (defaulting to last 6 months)
        end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
        if summary[:total_income] > 0
          summary[:savings_rate] = {
            percentage: ((summary[:total_income] - summary[:total_expenses]) / summary[:total_income] * 100).round(2),
            amount: (summary[:total_income] - summary[:total_expenses]).round(2)
          }

          # Add savings rate health indicator
          summary[:savings_rate][:status] = determine_savings_rate_health(summary[:savings_rate][:percentage])

          # Add simple benchmark comparison
          summary[:savings_rate][:benchmark] = {
            minimum_recommended: 10,
            ideal_recommended: 20,
            comparison: compare_to_benchmark(summary[:savings_rate][:percentage])
          }
        else
          summary[:savings_rate] = {
            percentage: 0,
            amount: -summary[:total_expenses],
            status: "no_income",
            note: "No income recorded during this period"
          }
        end

        # Handle different timeframe options
        case params[:timeframe]
        when 'year_to_date'
          start_date = Date.new(end_date.year, 1, 1)
          period_type = 'month'
          format_string = '%b'  # Month abbreviation (Jan, Feb)
        when 'past_year'
          start_date = end_date - 1.year
          period_type = 'month'
          format_string = '%b'
        when 'custom'
          start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : (end_date - 6.months)
          # Determine appropriate grouping based on date range
          days_diff = (end_date - start_date).to_i
          if days_diff <= 31
            period_type = 'day'
            format_string = '%d'  # Day of month
          elsif days_diff <= 365
            period_type = 'month'
            format_string = '%b'
          else
            period_type = 'year'
            format_string = '%Y'
          end
        else # default to last 6 months
          start_date = end_date - 6.months
          period_type = 'month'
          format_string = '%b'
        end

        # Get all transactions between dates
        transactions = current_user.financial_transactions
                                  .where(date: start_date..end_date)

        # Calculate overall totals
        total_income = transactions.income.sum(:amount)
        total_expenses = transactions.expense.sum(:amount).abs

        # Group data by period (day, month or year)
        periods_data = []

        case period_type
        when 'day'
          # Group by day
          (start_date..end_date).each do |date|
            day_transactions = transactions.where(date: date)
            income = day_transactions.income.sum(:amount)
            expenses = day_transactions.expense.sum(:amount).abs

            periods_data << {
              period: date.strftime(format_string),
              date: date,
              income: income,
              expenses: expenses,
              net: income - expenses,
              transaction_count: day_transactions.count
            }
          end
        when 'month'
          # Group by month
          current_date = start_date.beginning_of_month
          while current_date <= end_date
            month_end = [current_date.end_of_month, end_date].min
            month_transactions = transactions.where(date: current_date..month_end)

            income = month_transactions.income.sum(:amount)
            expenses = month_transactions.expense.sum(:amount).abs

            periods_data << {
              period: current_date.strftime(format_string),
              date: current_date,
              income: income,
              expenses: expenses,
              net: income - expenses,
              transaction_count: month_transactions.count
            }

            current_date = current_date.next_month.beginning_of_month
          end
        when 'year'
          # Group by year
          current_date = start_date.beginning_of_year
          while current_date <= end_date
            year_end = [current_date.end_of_year, end_date].min
            year_transactions = transactions.where(date: current_date..year_end)

            income = year_transactions.income.sum(:amount)
            expenses = year_transactions.expense.sum(:amount).abs

            periods_data << {
              period: current_date.strftime(format_string),
              date: current_date,
              income: income,
              expenses: expenses,
              net: income - expenses,
              transaction_count: year_transactions.count
            }

            current_date = current_date.next_year.beginning_of_year
          end
        end

        # Calculate trends and insights
        income_trend = calculate_trend(periods_data.map { |p| p[:income] })
        expense_trend = calculate_trend(periods_data.map { |p| p[:expenses] })

        # Find top income and expense categories
        top_income_categories = get_top_categories(transactions.income, 3)
        top_expense_categories = get_top_categories(transactions.expense, 3)

        # Prepare the response
        response = {
          summary: {
            start_date: start_date,
            end_date: end_date,
            total_income: total_income,
            total_expenses: total_expenses,
            net_result: total_income - total_expenses,
            income_expense_ratio: total_income > 0 ? (total_expenses / total_income * 100).round(2) : 0,
            savings_rate: total_income > 0 ? (((total_income - total_expenses) / total_income) * 100).round(2) : 0,
            financial_health: determine_financial_health(total_income, total_expenses),
            transaction_count: transactions.count
          },
          period_data: periods_data,
          trends: {
            income: income_trend,
            expenses: expense_trend,
            message: generate_trend_insight(income_trend, expense_trend)
          },
          top_categories: {
            income: top_income_categories,
            expenses: top_expense_categories
          },
          averages: {
            monthly_income: calculate_monthly_average(periods_data, :income, period_type),
            monthly_expenses: calculate_monthly_average(periods_data, :expenses, period_type)
          }
        }

        # Include monthly/yearly comparison if period_type is month or year
        if period_type == 'month' || period_type == 'year'
          response[:comparison] = generate_comparison(period_type, start_date, end_date)
        end

        render json: response
      end

      def category_spending_breakdown
        # Handle date parameters
        if params[:year].present? && params[:month].present?
          start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
          end_date = start_date.end_of_month
          period_type = 'specific_month'
        elsif params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          period_type = 'custom_range'
        elsif params[:timeframe].present?
          end_date = Date.current
          case params[:timeframe]
          when 'month_to_date'
            start_date = Date.current.beginning_of_month
            period_type = 'month_to_date'
          when 'last_30_days'
            start_date = Date.current - 30.days
            period_type = 'last_30_days'
          when 'last_90_days'
            start_date = Date.current - 90.days
            period_type = 'last_90_days'
          when 'year_to_date'
            start_date = Date.current.beginning_of_year
            period_type = 'year_to_date'
          when 'last_12_months'
            start_date = Date.current - 1.year
            period_type = 'last_12_months'
          else
            start_date = Date.current.beginning_of_month
            period_type = 'month_to_date'
          end
        else
          # Default to current month
          start_date = Date.current.beginning_of_month
          end_date = Date.current.end_of_month
          period_type = 'current_month'
        end

        # Get all transactions in date range
        transactions = current_user.financial_transactions
                                  .where(date: start_date..end_date)

        # Calculate total expenses for the period
        total_expenses = transactions.expense.sum(:amount).abs

        # Get all user's categories (including those with no spending)
        categories = current_user.categories

        # Prepare category data
        category_spending = []

        categories.each do |category|
          # Get transactions for this category
          category_transactions = transactions.expense.where(category_id: category.id)
          amount_spent = category_transactions.sum(:amount).abs
          transaction_count = category_transactions.count

          # Skip categories with specific filtering if requested
          next if params[:exclude_zero] == 'true' && amount_spent == 0

          # Basic category spending data
          category_data = {
            id: category.id,
            name: category.name,
            color: category.color,
            amount: amount_spent,
            transaction_count: transaction_count,
            percentage: total_expenses > 0 ? ((amount_spent / total_expenses) * 100).round(2) : 0,
            has_transactions: transaction_count > 0
          }

          # Add additional data if category has transactions
          if transaction_count > 0
            # Get first and last transaction date
            first_transaction = category_transactions.order(date: :asc).first
            last_transaction = category_transactions.order(date: :desc).first

            # Calculate average transaction amount
            average_transaction = amount_spent / transaction_count

            # Find largest transaction
            largest_transaction = category_transactions.order(amount: :desc).first

            # Get spending frequency (transactions per day in the period)
            days_in_period = (end_date - start_date).to_i + 1
            frequency_per_day = transaction_count / days_in_period.to_f

            # Get historical spending data for trends
            historical_data = get_historical_category_data(category.id, start_date, 3)

            # Add budget information if available
            budget = if start_date.beginning_of_month == end_date.beginning_of_month
                       current_user.budgets.find_by(
                         category_id: category.id,
                         year: start_date.year,
                         month: start_date.month
                       )
                     end

            # Add these additional metrics
            category_data.merge!({
              details: {
                first_transaction_date: first_transaction.date,
                last_transaction_date: last_transaction.date,
                average_transaction_amount: average_transaction.round(2),
                largest_transaction: {
                  id: largest_transaction.id,
                  title: largest_transaction.title,
                  amount: largest_transaction.amount.abs,
                  date: largest_transaction.date
                },
                spending_frequency: {
                  transactions_per_day: frequency_per_day.round(3),
                  days_per_transaction: (frequency_per_day > 0 ? (1 / frequency_per_day) : 0).round(2),
                  formatted: frequency_per_day >= 1 ?
                           "#{frequency_per_day.round(2)} times per day" :
                           "Once every #{(1 / frequency_per_day).round(2)} days"
                },
                historical_trend: {
                  data: historical_data,
                  trend_direction: calculate_trend_direction(historical_data.map { |h| h[:amount] }),
                  average_monthly: historical_data.sum { |m| m[:amount] } / historical_data.size
                }
              }
            })

            # Add budget information if available
            if budget
              category_data[:budget] = {
                amount: budget.amount,
                remaining: budget.amount - amount_spent,
                usage_percentage: ((amount_spent / budget.amount) * 100).round(2),
                status: budget_status(amount_spent, budget.amount)
              }
            end
          end

          category_spending << category_data
        end

        # Sort categories by amount spent (descending)
        category_spending.sort_by! { |cs| -cs[:amount] }

        # Group categories by spending level
        top_spending = category_spending.first(3)
        mid_spending = category_spending[3..7]
        low_spending = category_spending[8..-1] || []

        # Prepare response
        response = {
          period: {
            start_date: start_date,
            end_date: end_date,
            type: period_type
          },
          summary: {
            total_expenses: total_expenses,
            category_count: categories.count,
            categories_with_spending: category_spending.count { |cs| cs[:transaction_count] > 0 },
            average_per_category: category_spending.sum { |cs| cs[:amount] } /
                                 category_spending.count { |cs| cs[:transaction_count] > 0 }
          },
          spending_distribution: {
            top_categories: top_spending.map { |c| c[:name] },
            top_categories_percentage: top_spending.sum { |c| c[:percentage] }.round(2),
            mid_tier_percentage: mid_spending.sum { |c| c[:percentage] }.round(2),
            low_tier_percentage: low_spending.sum { |c| c[:percentage] }.round(2)
          },
          categories: category_spending
        }

        # Add spending insights section
        response[:insights] = generate_spending_insights(category_spending, total_expenses)

        render json: response
      end

      def category_detail
        # Find the category
        category = current_user.categories.find(params[:category_id])

        # Get date range parameters
        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
        elsif params[:year].present? && params[:month].present?
          start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
          end_date = start_date.end_of_month
        elsif params[:timeframe].present?
          end_date = Date.current
          case params[:timeframe]
          when 'month_to_date'
            start_date = Date.current.beginning_of_month
          when 'last_30_days'
            start_date = Date.current - 30.days
          when 'last_90_days'
            start_date = Date.current - 90.days
          when 'year_to_date'
            start_date = Date.current.beginning_of_year
          when 'last_12_months'
            start_date = Date.current - 1.year
          else
            start_date = Date.current.beginning_of_month
          end
        else
          # Default to last 12 months for detailed category analysis
          start_date = Date.current - 1.year
          end_date = Date.current
        end

        # Get all transactions for this category in date range
        transactions = current_user.financial_transactions
                                  .expense
                                  .where(category_id: category.id)
                                  .where(date: start_date..end_date)
                                  .order(date: :desc)

        # Calculate metrics
        total_spent = transactions.sum(:amount).abs
        transaction_count = transactions.count
        average_transaction = transaction_count > 0 ? total_spent / transaction_count : 0

        # Get monthly spending for this category
        monthly_spending = []
        current_date = start_date.beginning_of_month

        while current_date <= end_date
          month_end = [current_date.end_of_month, end_date].min
          month_transactions = transactions.where(date: current_date..month_end)

          monthly_spending << {
            month: current_date.strftime("%b %Y"),
            amount: month_transactions.sum(:amount).abs,
            transaction_count: month_transactions.count,
            average_transaction: month_transactions.count > 0 ?
                               (month_transactions.sum(:amount).abs / month_transactions.count).round(2) : 0
          }

          current_date = current_date.next_month.beginning_of_month
        end

        # Get day-of-week distribution
        day_distribution = [0, 0, 0, 0, 0, 0, 0]  # Sunday to Saturday

        transactions.each do |t|
          day_distribution[t.date.wday] += t.amount.abs
        end

        # Calculate day-of-week percentages
        day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        day_percentages = total_spent > 0 ?
                        day_distribution.map { |amount| ((amount / total_spent) * 100).round(2) } :
                        [0, 0, 0, 0, 0, 0, 0]

        # Get budget history
        budget_history = []
        current_date = start_date.beginning_of_month

        while current_date <= end_date
          budget = current_user.budgets.find_by(
            category_id: category.id,
            year: current_date.year,
            month: current_date.month
          )

          month_transactions = current_user.financial_transactions
                                         .expense
                                         .where(category_id: category.id)
                                         .where(date: current_date.beginning_of_month..current_date.end_of_month)

          month_spent = month_transactions.sum(:amount).abs

          budget_data = {
            month: current_date.strftime("%b %Y"),
            spent: month_spent
          }

          if budget
            budget_data[:budget_amount] = budget.amount
            budget_data[:remaining] = budget.amount - month_spent
            budget_data[:percentage_used] = ((month_spent / budget.amount) * 100).round(2)
            budget_data[:status] = budget_status(month_spent, budget.amount)
          end

          budget_history << budget_data
          current_date = current_date.next_month.beginning_of_month
        end

        # Get most common merchants/descriptions
        merchant_analysis = {}

        transactions.each do |t|
          description = t.title.to_s.strip
          merchant_analysis[description] ||= { count: 0, total: 0 }
          merchant_analysis[description][:count] += 1
          merchant_analysis[description][:total] += t.amount.abs
        end

        top_merchants = merchant_analysis.map do |name, data|
          {
            name: name,
            transaction_count: data[:count],
            total_spent: data[:total],
            average_transaction: (data[:total] / data[:count]).round(2),
            percentage: total_spent > 0 ? ((data[:total] / total_spent) * 100).round(2) : 0
          }
        end.sort_by { |m| -m[:total_spent] }.first(5)

        # Prepare the response
        response = {
          category: {
            id: category.id,
            name: category.name,
            color: category.color
          },
          period: {
            start_date: start_date,
            end_date: end_date
          },
          summary: {
            total_spent: total_spent,
            transaction_count: transaction_count,
            average_transaction: average_transaction.round(2),
            first_transaction: transactions.order(date: :asc).first,
            last_transaction: transactions.order(date: :desc).first,
            largest_transaction: transactions.order(amount: :desc).first
          },
          monthly_spending: monthly_spending,
          day_of_week_analysis: day_names.zip(day_distribution, day_percentages).map do |day, amount, percentage|
            {
              day: day,
              amount: amount,
              percentage: percentage
            }
          end,
          budget_history: budget_history,
          top_merchants: top_merchants,
          transactions: transactions.limit(10)  # Limited recent transactions
        }

        # Add insights specific to this category
        response[:insights] = generate_category_insights(
          category,
          monthly_spending,
          day_distribution,
          budget_history,
          top_merchants
        )

        render json: response
      end

      def monthly_summary
        # Existing implementation...

        # Add trend analysis data
        response[:trends] = {
          spending: calculate_spending_trends(current_user, start_date),
          income: calculate_income_trends(current_user, start_date),
          top_changing_categories: identify_changing_categories(current_user, start_date)
        }

        render json: response
      end

      def savings_rate_analysis
        # Parse date ranges using our existing DateRangeReportable concern

        # Calculate savings rate for the requested period
        transactions = current_user.financial_transactions.where(date: @start_date..@end_date)
        total_income = transactions.income.sum(:amount)
        total_expenses = transactions.expense.sum(:amount).abs

        if total_income > 0
          current_rate = ((total_income - total_expenses) / total_income * 100).round(2)
        else
          current_rate = 0
        end

        # Get historical data for comparison
        historical_rates = calculate_historical_savings_rates(@start_date, @end_date)

        # Calculate savings rate by income source
        income_source_breakdown = calculate_savings_rate_by_income_source(@start_date, @end_date)

        # Calculate savings rate trend
        monthly_trend = calculate_monthly_savings_rate_trend(@start_date, @end_date)

        # Add projections based on current rate
        savings_projections = calculate_savings_projections(current_rate, total_income / ((@end_date - @start_date).to_i + 1) * 30.44) # Monthly avg income

        # Build response
        response = {
          date_range: @date_range_metadata,
          current_period: {
            income: total_income,
            expenses: total_expenses,
            savings: total_income - total_expenses,
            savings_rate: current_rate,
            status: determine_savings_rate_health(current_rate)
          },
          historical_comparison: {
            previous_period: historical_rates[:previous_period],
            same_period_last_year: historical_rates[:same_period_last_year],
            twelve_month_average: historical_rates[:twelve_month_average],
            all_time_average: historical_rates[:all_time],
            best_rate: historical_rates[:best],
            worst_rate: historical_rates[:worst]
          },
          benchmarks: {
            minimum_recommended: 10,
            ideal_recommended: 20,
            comparison_to_minimum: current_rate >= 10 ? "meets_or_exceeds" : "below",
            comparison_to_ideal: current_rate >= 20 ? "meets_or_exceeds" : "below",
            percentile: calculate_savings_rate_percentile(current_rate)
          },
          trends: {
            monthly_rates: monthly_trend,
            direction: determine_trend_direction(monthly_trend.map { |m| m[:rate] }),
            volatility: calculate_rate_volatility(monthly_trend.map { |m| m[:rate] })
          },
          income_source_analysis: income_source_breakdown,
          projections: savings_projections,
          insights: generate_savings_rate_insights(current_rate, historical_rates, monthly_trend)
        }

        render json: response
      end

      def summary
        cache_key = "user_#{current_user.id}_summary_#{@start_date.to_s}_#{@end_date.to_s}"
        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          # Generate report
          # ...
          response.as_json
        end

        render json: Rails.cache.read(cache_key)

        response[:financial_health] = {
          debt_to_income_ratio: {
            value: calculate_debt_to_income_ratio(current_user, @start_date, @end_date),
            status: determine_dti_status(debt_to_income)
          },
          emergency_fund_coverage: {
            value: calculate_emergency_fund_coverage(current_user),
            status: determine_emergency_fund_status(emergency_fund_coverage)
          },
          financial_resilience_score: {
            value: calculate_financial_resilience_score(...),
            status: determine_resilience_status(financial_resilience_score)
          }
        }

        render json: response
      end

      private

      def set_pagination_headers
        return unless @pagy

        response.headers['X-Total-Count'] = @pagy.total_count.to_s
        response.headers['X-Total-Pages'] = @pagy.total_pages.to_s
        response.headers['X-Current-Page'] = @pagy.current_page.to_s
        response.headers['X-Per-Page'] = @pagy.limit_value.to_s

        # Link headers omitted for brevity (same as in TransactionsController)
      end

      def calculate_historical_savings_rates(current_start, current_end)
        # Calculate previous period (same length as current period)
        period_length = (current_end - current_start).to_i + 1
        previous_end = current_start - 1.day
        previous_start = previous_end - (period_length - 1).days

        # Calculate same period last year
        last_year_start = current_start - 1.year
        last_year_end = current_end - 1.year

        # Get previous period rate
        previous_period_rate = calculate_rate_for_period(previous_start, previous_end)

        # Get same period last year rate
        last_year_rate = calculate_rate_for_period(last_year_start, last_year_end)

        # Get 12-month rolling average
        twelve_month_start = current_end - 1.year
        twelve_month_rate = calculate_rate_for_period(twelve_month_start, current_end)

        # Get all-time average
        first_transaction_date = current_user.financial_transactions.minimum(:date) || current_user.created_at.to_date
        all_time_rate = calculate_rate_for_period(first_transaction_date, current_end)

        # Get best and worst monthly rates
        monthly_rates = []
        date = first_transaction_date.beginning_of_month
        while date <= current_end
          month_end = [date.end_of_month, current_end].min
          monthly_rates << {
            period: "#{date.strftime('%b %Y')}",
            rate: calculate_rate_for_period(date, month_end)
          }
          date = date.next_month.beginning_of_month
          break if date > current_end
        end

        best_rate = monthly_rates.max_by { |r| r[:rate] }
        worst_rate = monthly_rates.min_by { |r| r[:rate] }

        {
          previous_period: {
            start_date: previous_start,
            end_date: previous_end,
            rate: previous_period_rate,
            difference: current_rate - previous_period_rate
          },
          same_period_last_year: {
            start_date: last_year_start,
            end_date: last_year_end,
            rate: last_year_rate,
            difference: current_rate - last_year_rate
          },
          twelve_month_average: {
            start_date: twelve_month_start,
            end_date: current_end,
            rate: twelve_month_rate,
            difference: current_rate - twelve_month_rate
          },
          all_time: {
            start_date: first_transaction_date,
            end_date: current_end,
            rate: all_time_rate
          },
          best: best_rate,
          worst: worst_rate
        }
      end

      def calculate_rate_for_period(start_date, end_date)
        transactions = current_user.financial_transactions.where(date: start_date..end_date)
        income = transactions.income.sum(:amount)
        expenses = transactions.expense.sum(:amount).abs

        return 0 if income <= 0

        ((income - expenses) / income * 100).round(2)
      end

      def calculate_savings_rate_by_income_source(start_date, end_date)
        # Group transactions by category for income sources
        income_categories = current_user.categories.where(id: current_user.financial_transactions
                                                            .income
                                                            .where(date: start_date..end_date)
                                                            .select(:category_id))

        # Total expenses for the period
        total_expenses = current_user.financial_transactions
                                    .expense
                                    .where(date: start_date..end_date)
                                    .sum(:amount).abs

        # Calculate effective savings rate by income source
        income_sources = []

        income_categories.each do |category|
          category_income = current_user.financial_transactions
                                       .income
                                       .where(date: start_date..end_date, category_id: category.id)
                                       .sum(:amount)

          # Attribute expenses proportionally to each income source
          if category_income > 0
            source_data = {
              category_id: category.id,
              category_name: category.name,
              income_amount: category_income,
              # Calculate how much of total expenses would be attributed to this income source
              estimated_expenses: total_expenses * (category_income / total_income),
              savings_rate: ((category_income - (total_expenses * (category_income / total_income))) / category_income * 100).round(2)
            }

            income_sources << source_data
          end
        end

        income_sources
      end

      def calculate_monthly_savings_rate_trend(start_date, end_date)
        # Determine appropriate period granularity based on date range length
        days_in_range = (end_date - start_date).to_i + 1

        if days_in_range <= 31
          # For short ranges, show daily rates
          return calculate_daily_savings_rate_trend(start_date, end_date)
        elsif days_in_range <= 366
          # For up to a year, show monthly rates
          return calculate_trend_by_month(start_date, end_date)
        else
          # For longer periods, show quarterly rates
          return calculate_trend_by_quarter(start_date, end_date)
        end
      end

      def calculate_trend_by_month(start_date, end_date)
        monthly_trend = []
        current_date = start_date.beginning_of_month

        while current_date <= end_date
          month_end = [current_date.end_of_month, end_date].min

          transactions = current_user.financial_transactions
                                    .where(date: current_date..month_end)

          income = transactions.income.sum(:amount)
          expenses = transactions.expense.sum(:amount).abs

          rate = income > 0 ? ((income - expenses) / income * 100).round(2) : 0

          monthly_trend << {
            period: current_date.strftime("%b %Y"),
            start_date: current_date,
            end_date: month_end,
            income: income,
            expenses: expenses,
            savings: income - expenses,
            rate: rate,
            status: determine_savings_rate_health(rate)
          }

          current_date = current_date.next_month.beginning_of_month
          break if current_date > end_date
        end

        monthly_trend
      end

      def calculate_savings_projections(current_rate, monthly_income)
        # Project future savings based on current rate
        monthly_savings = monthly_income * (current_rate / 100)

        projections = {
          one_year: monthly_savings * 12,
          five_years: monthly_savings * 12 * 5,
          ten_years: monthly_savings * 12 * 10,
          retirement_impact: estimate_retirement_impact(current_rate, monthly_income)
        }

        # Add goal-based projections if user has financial goals
        if current_user.financial_goals.any?
          projections[:goals] = []

          current_user.financial_goals.each do |goal|
            if monthly_savings > 0
              months_to_goal = goal.target_amount / monthly_savings
              projections[:goals] << {
                goal_id: goal.id,
                goal_name: goal.name,
                target_amount: goal.target_amount,
                estimated_months_to_achieve: months_to_goal.round,
                estimated_date: Date.current + months_to_goal.months,
                progress_percentage: ((goal.current_amount / goal.target_amount) * 100).round(2)
              }
            end
          end
        end

        projections
      end

      def estimate_retirement_impact(savings_rate, monthly_income)
        # Simple retirement calculator
        annual_savings = monthly_income * 12 * (savings_rate / 100)
        years_to_retirement = 65 - current_user.age.to_i  # Assuming retirement at 65

        # Very simplified calculation - real implementations would use compound interest
        expected_retirement_savings = annual_savings * years_to_retirement

        {
          estimated_retirement_savings: expected_retirement_savings,
          years_to_retirement: years_to_retirement,
          monthly_retirement_income: (expected_retirement_savings * 0.04) / 12  # Using the 4% rule
        }
      end

      def calculate_savings_rate_percentile(rate)
        # In a real implementation, this would compare against real benchmark data
        # This is a simplified implementation
        case
        when rate < 0
          "bottom_10"
        when rate < 5
          "bottom_25"
        when rate < 10
          "below_average"
        when rate < 15
          "average"
        when rate < 20
          "above_average"
        when rate < 30
          "top_25"
        else
          "top_10"
        end
      end

      def generate_savings_rate_insights(current_rate, historical_rates, trend_data)
        insights = []

        # Check for improvement or decline
        if historical_rates[:previous_period][:rate] > 0
          difference = current_rate - historical_rates[:previous_period][:rate]
          if difference > 5
            insights << {
              type: "improvement",
              title: "Significant Improvement",
              message: "Your savings rate has improved by #{difference.abs.round(1)} percentage points compared to the previous period."
            }
          elsif difference < -5
            insights << {
              type: "decline",
              title: "Significant Decline",
              message: "Your savings rate has decreased by #{difference.abs.round(1)} percentage points compared to the previous period."
            }
          end
        end

        # Check against benchmarks
        if current_rate < 10
          insights << {
            type: "benchmark_comparison",
            title: "Below Recommended Minimum",
            message: "Your current savings rate of #{current_rate}% is below the recommended minimum of 10%. Consider reviewing your budget."
          }
        elsif current_rate >= 20
          insights << {
            type: "benchmark_comparison",
            title: "Excellent Savings Rate",
            message: "Your current savings rate of #{current_rate}% meets or exceeds the ideal recommendation of 20%. Great job!"
          }
        end

        # Check for best/worst performance
        if current_rate >= historical_rates[:best][:rate] - 1  # Within 1% of best
          insights << {
            type: "historical_comparison",
            title: "Near Personal Best",
            message: "Your current savings rate is close to your best recorded rate of #{historical_rates[:best][:rate]}% from #{historical_rates[:best][:period]}."
          }
        elsif current_rate <= historical_rates[:worst][:rate] + 1  # Within 1% of worst
          insights << {
            type: "historical_comparison",
            title: "Near Personal Low",
            message: "Your current savings rate is close to your lowest recorded rate of #{historical_rates[:worst][:rate]}% from #{historical_rates[:worst][:period]}."
          }
        end

        # Check for trends
        if trend_data.size >= 3
          recent_trend = determine_trend_direction(trend_data.last(3).map { |t| t[:rate] })

          if recent_trend == "consistently_increasing"
            insights << {
              type: "trend",
              title: "Positive Trend",
              message: "Your savings rate has been consistently increasing over the past three periods."
            }
          elsif recent_trend == "consistently_decreasing"
            insights << {
              type: "trend",
              title: "Negative Trend",
              message: "Your savings rate has been consistently decreasing over the past three periods."
            }
          end
        end

        insights
      end

      def determine_savings_rate_health(rate)
        case
        when rate < 0
          "negative"
        when rate < 5
          "critical"
        when rate < 10
          "low"
        when rate < 15
          "adequate"
        when rate < 20
          "good"
        else
          "excellent"
        end
      end

      def compare_to_benchmark(rate)
        if rate < 10
          "below_minimum"
        elsif rate < 20
          "meets_minimum"
        else
          "meets_ideal"
        end
      end

      def calculate_spending_trends(user, current_period_start)
        # Define comparison periods
        current_period_end = current_period_start.end_of_month
        previous_period_start = current_period_start.prev_month.beginning_of_month
        previous_period_end = previous_period_start.end_of_month
        year_ago_period_start = current_period_start.prev_year.beginning_of_month
        year_ago_period_end = year_ago_period_start.end_of_month

        # Get transaction data for each period
        current_spending = user.financial_transactions
                              .expense
                              .where(date: current_period_start..current_period_end)
                              .sum(:amount).abs

        previous_spending = user.financial_transactions
                                .expense
                                .where(date: previous_period_start..previous_period_end)
                                .sum(:amount).abs

        year_ago_spending = user.financial_transactions
                                .expense
                                .where(date: year_ago_period_start..year_ago_period_end)
                                .sum(:amount).abs

        # Calculate trend metrics
        mom_change = calculate_percentage_change(current_spending, previous_spending)
        yoy_change = calculate_percentage_change(current_spending, year_ago_spending)

        # Get 6-month trend for visualization
        six_month_trend = []
        6.times do |i|
          month_date = current_period_start.prev_month(5-i)
          month_spending = user.financial_transactions
                              .expense
                              .where(date: month_date.beginning_of_month..month_date.end_of_month)
                              .sum(:amount).abs

          six_month_trend << {
            month: month_date.strftime("%b %Y"),
            amount: month_spending
          }
        end

        # Perform trend analysis
        trend_direction = determine_trend_direction(six_month_trend.map { |t| t[:amount] })

        {
          current_period: {
            start_date: current_period_start,
            end_date: current_period_end,
            amount: current_spending
          },
          comparisons: {
            previous_month: {
              start_date: previous_period_start,
              end_date: previous_period_end,
              amount: previous_spending,
              change_percentage: mom_change,
              change_amount: current_spending - previous_spending,
              direction: mom_change > 0 ? "increased" : (mom_change < 0 ? "decreased" : "unchanged")
            },
            previous_year: {
              start_date: year_ago_period_start,
              end_date: year_ago_period_end,
              amount: year_ago_spending,
              change_percentage: yoy_change,
              change_amount: current_spending - year_ago_spending,
              direction: yoy_change > 0 ? "increased" : (yoy_change < 0 ? "decreased" : "unchanged")
            }
          },
          six_month_trend: six_month_trend,
          trend_analysis: {
            direction: trend_direction,
            description: trend_description(trend_direction, "spending"),
            velocity: calculate_trend_velocity(six_month_trend.map { |t| t[:amount] })
          }
        }
      end

      def calculate_income_trends(user, current_period_start)
        # Similar implementation for income trends
        # ...
      end

      def identify_changing_categories(user, current_period_start)
        # Define comparison periods
        current_period_end = current_period_start.end_of_month
        previous_period_start = current_period_start.prev_month.beginning_of_month
        previous_period_end = previous_period_start.end_of_month

        # Get current period category spending
        current_categories = user.financial_transactions
                                .expense
                                .where(date: current_period_start..current_period_end)
                                .joins(:category)
                                .group('categories.id', 'categories.name')
                                .select('categories.id, categories.name, SUM(amount) as total_spent')

        # Get previous period category spending
        previous_categories = user.financial_transactions
                                 .expense
                                 .where(date: previous_period_start..previous_period_end)
                                 .joins(:category)
                                 .group('categories.id', 'categories.name')
                                 .select('categories.id, categories.name, SUM(amount) as total_spent')

        # Find categories with significant changes
        changed_categories = []

        current_categories.each do |current|
          previous = previous_categories.find { |p| p.id == current.id }

          if previous
            change_percentage = calculate_percentage_change(current.total_spent, previous.total_spent)

            # Only include categories with significant changes (>10%)
            if change_percentage.abs >= 10
              changed_categories << {
                id: current.id,
                name: current.name,
                current_amount: current.total_spent.abs,
                previous_amount: previous.total_spent.abs,
                change_percentage: change_percentage,
                direction: change_percentage > 0 ? "increased" : "decreased"
              }
            end
          else
            # New category
            changed_categories << {
              id: current.id,
              name: current.name,
              current_amount: current.total_spent.abs,
              previous_amount: 0,
              change_percentage: 100,
              direction: "new"
            }
          end
        end

        # Sort by absolute percentage change (descending)
        changed_categories.sort_by! { |c| -c[:change_percentage].abs }

        # Limit to top 5 changes
        changed_categories.first(5)
      end

      def calculate_percentage_change(current, previous)
        return 0 if previous == 0 && current == 0
        return 100 if previous == 0 && current > 0
        return -100 if current == 0 && previous > 0

        ((current - previous) / previous.to_f * 100).round(2)
      end

      def determine_trend_direction(amounts)
        return "insufficient_data" if amounts.size < 3

        # Calculate linear regression to find trend
        x_values = (0...amounts.length).to_a
        slope = calculate_linear_regression_slope(x_values, amounts)

        # Determine trend based on slope and consistency
        if slope.abs < 0.05 * (amounts.sum / amounts.size)
          "stable"
        elsif slope > 0
          consistency = trend_consistency(amounts)
          consistency >= 0.7 ? "consistently_increasing" : "moderately_increasing"
        else
          consistency = trend_consistency(amounts.map { |a| -a })  # Invert for decreasing
          consistency >= 0.7 ? "consistently_decreasing" : "moderately_decreasing"
        end
      end

      def calculate_linear_regression_slope(x_values, y_values)
        n = x_values.length
        sum_x = x_values.sum
        sum_y = y_values.sum
        sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
        sum_x_squared = x_values.map { |x| x**2 }.sum

        (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x**2)
      end

      def trend_consistency(values)
        increases = 0

        (1...values.length).each do |i|
          increases += 1 if values[i] > values[i-1]
        end

        increases.to_f / (values.length - 1)
      end

      def trend_description(trend_direction, metric_type)
        case trend_direction
        when "consistently_increasing"
          "Your #{metric_type} has been steadily increasing over the past six months."
        when "moderately_increasing"
          "Your #{metric_type} shows an overall increasing pattern, though with some fluctuations."
        when "stable"
          "Your #{metric_type} has remained relatively stable over the past six months."
        when "moderately_decreasing"
          "Your #{metric_type} shows an overall decreasing pattern, though with some fluctuations."
        when "consistently_decreasing"
          "Your #{metric_type} has been steadily decreasing over the past six months."
        else
          "Not enough data to determine a reliable trend."
        end
      end

      def calculate_trend_velocity(values)
        return 0 if values.size < 3

        # Calculate average rate of change per period
        changes = []
        (1...values.length).each do |i|
          changes << (values[i] - values[i-1])
        end

        # Average monthly change
        avg_change = changes.sum / changes.size.to_f

        # Normalize as percentage of average value
        avg_value = values.sum / values.size.to_f
        (avg_change / avg_value * 100).round(2)
      end

      def generate_category_insights(category, monthly_data, day_distribution, budget_history, merchants)
        insights = []

        # Detect spending trend
        if monthly_data.size >= 3
          recent_months = monthly_data.last(3)
          trend = calculate_trend_direction(recent_months.map { |m| m[:amount] })

          insights << {
            type: "spending_trend",
            title: "Recent Spending Trend",
            message: case trend
                    when "increasing"
                      "Your spending in #{category.name} has been increasing over the past three months."
                    when "decreasing"
                      "Your spending in #{category.name} has been decreasing over the past three months."
                    else
                      "Your spending in #{category.name} has been stable over the past three months."
                    end
          }
        end

        # Detect day of week patterns
        max_day_index = day_distribution.index(day_distribution.max)
        if day_distribution.max > 0 && (day_distribution.max / day_distribution.sum.to_f) > 0.3
          day_name = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][max_day_index]
          insights << {
            type: "day_pattern",
            title: "Day of Week Pattern",
            message: "You tend to spend most on #{category.name} on #{day_name}s (#{((day_distribution.max / day_distribution.sum.to_f) * 100).round(2)}% of spending)."
          }
        end

        # Budget consistency
        budgeted_months = budget_history.select { |b| b[:budget_amount].present? }
        over_budget_months = budgeted_months.select { |b| b[:status] == "exceeded" }

        if budgeted_months.size > 0 && over_budget_months.size > 0
          percentage = ((over_budget_months.size / budgeted_months.size.to_f) * 100).round(2)
          insights << {
            type: "budget_consistency",
            title: "Budget Consistency",
            message: "You've exceeded your budget for #{category.name} in #{over_budget_months.size} out of #{budgeted_months.size} months (#{percentage}%)."
          }
        end

        # Merchant concentration
        if merchants.any? && merchants.first[:percentage] > 50
          insights << {
            type: "merchant_concentration",
            title: "Merchant Concentration",
            message: "#{merchants.first[:name]} accounts for #{merchants.first[:percentage]}% of your spending in this category."
          }
        end

        insights
      end

      def calculate_trend_direction(values)
        return "no_data" if values.empty? || values.sum == 0
        return "stable" if values.count < 2

        # Calculate trend direction based on slope
        x_values = (0...values.length).to_a
        y_values = values

        # Simple linear regression to determine slope
        n = x_values.length
        sum_x = x_values.sum
        sum_y = y_values.sum
        sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
        sum_x_squared = x_values.map { |x| x**2 }.sum

        # Calculate slope
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x**2)

        # Determine trend based on slope
        if slope.abs < 0.05 * (sum_y / n)  # Less than 5% change is considered stable
          "stable"
        elsif slope > 0
          "increasing"
        else
          "decreasing"
        end
      end

      def get_historical_category_data(category_id, end_date, months_back)
        result = []

        months_back.times do |i|
          month_date = end_date.beginning_of_month - i.months
          month_start = month_date.beginning_of_month
          month_end = month_date.end_of_month

          # Get transactions for this month and category
          month_transactions = current_user.financial_transactions
                                         .expense
                                         .where(category_id: category_id)
                                         .where(date: month_start..month_end)

          amount_spent = month_transactions.sum(:amount).abs
          transaction_count = month_transactions.count

          result << {
            month: month_date.strftime("%b %Y"),
            amount: amount_spent,
            transaction_count: transaction_count
          }
        end

        # Return in chronological order (oldest first)
        result.reverse
      end

      def budget_status(amount_spent, budget_amount)
        usage_percentage = (amount_spent / budget_amount) * 100

        case
        when usage_percentage < 50
          "safe"
        when usage_percentage < 75
          "good"
        when usage_percentage < 90
          "warning"
        when usage_percentage < 100
          "critical"
        else
          "exceeded"
        end
      end

      def generate_spending_insights(category_data, total_expenses)
        return [] if category_data.empty? || total_expenses == 0

        insights = []

        # Find categories with significant spending (>15% of total)
        significant_categories = category_data.select { |c| c[:percentage] > 15 }
        if significant_categories.any?
          insights << {
            type: "significant_spending",
            title: "High Concentration of Spending",
            message: "#{significant_categories.count} #{significant_categories.count > 1 ? 'categories' : 'category'} (#{significant_categories.map { |c| c[:name] }.join(', ')}) account for #{significant_categories.sum { |c| c[:percentage] }.round(2)}% of your spending."
          }
        end

        # Find categories with increasing trends
        increasing_categories = category_data.select do |c|
          c[:details] && c[:details][:historical_trend] && c[:details][:historical_trend][:trend_direction] == "increasing"
        end

        if increasing_categories.any?
          insights << {
            type: "increasing_trends",
            title: "Increasing Spending Categories",
            message: "Your spending has been increasing in these categories: #{increasing_categories.map { |c| c[:name] }.join(', ')}. Consider reviewing these areas."
          }
        end

        # Find categories with budget issues
        over_budget_categories = category_data.select do |c|
          c[:budget] && (c[:budget][:status] == "critical" || c[:budget][:status] == "exceeded")
        end

        if over_budget_categories.any?
          insights << {
            type: "budget_concerns",
            title: "Budget Concerns",
            message: "You're #{over_budget_categories.any? { |c| c[:budget][:status] == "exceeded" } ? 'over budget' : 'approaching your budget'} in these categories: #{over_budget_categories.map { |c| c[:name] }.join(', ')}."
          }
        end

        # Find categories with no spending
        zero_spending = category_data.select { |c| c[:amount] == 0 }
        if zero_spending.count > 3
          insights << {
            type: "unused_categories",
            title: "Unused Categories",
            message: "You have #{zero_spending.count} categories with no spending in this period. Consider simplifying your categories."
          }
        end

        # Add more insights as needed

        insights
      end

      def calculate_trend(values)
        return "stable" if values.empty? || values.count < 2

        first_half = values.first(values.size / 2)
        second_half = values.last(values.size / 2)

        first_half_avg = first_half.sum / first_half.size.to_f
        second_half_avg = second_half.sum / second_half.size.to_f

        change_percentage = first_half_avg > 0 ?
                           ((second_half_avg - first_half_avg) / first_half_avg * 100).round(2) : 0

        if change_percentage.abs < 5
          "stable"
        elsif change_percentage > 0
          "increasing"
        else
          "decreasing"
        end
      end

      def generate_trend_insight(income_trend, expense_trend)
        case [income_trend, expense_trend]
        when ["increasing", "decreasing"]
          "Excellent trend: Your income is increasing while expenses are decreasing!"
        when ["increasing", "stable"]
          "Positive trend: Your income is increasing while expenses remain stable."
        when ["stable", "decreasing"]
          "Positive trend: Your expenses are decreasing while income remains stable."
        when ["increasing", "increasing"]
          "Mixed trend: Both your income and expenses are increasing."
        when ["decreasing", "decreasing"]
          "Caution: Both your income and expenses are decreasing."
        when ["stable", "increasing"]
          "Caution: Your expenses are increasing while income remains stable."
        when ["decreasing", "stable"]
          "Warning: Your income is decreasing while expenses remain stable."
        when ["decreasing", "increasing"]
          "Warning: Your income is decreasing while expenses are increasing!"
        else
          "Your finances appear stable."
        end
      end

      def get_top_categories(transactions_scope, limit)
        transactions_scope
          .joins(:category)
          .group('categories.id', 'categories.name', 'categories.color')
          .select('categories.id, categories.name, categories.color, SUM(amount) as total_amount, COUNT(*) as transaction_count')
          .order('total_amount DESC')
          .limit(limit)
          .map do |category|
            {
              id: category.id,
              name: category.name,
              color: category.color,
              amount: category.total_amount.abs,
              transaction_count: category.transaction_count,
              percentage: transactions_scope.sum(:amount) != 0 ?
                         ((category.total_amount.abs / transactions_scope.sum(:amount).abs) * 100).round(2) : 0
            }
          end
      end

      def calculate_monthly_average(periods_data, attribute, period_type)
        return 0 if periods_data.empty?

        total = periods_data.sum { |p| p[attribute] }

        # Convert to monthly average based on period type
        case period_type
        when 'day'
          # Convert daily data to monthly estimate (multiply by avg days per month)
          total / periods_data.size * 30.44
        when 'month'
          # Already monthly, just get the average
          total / periods_data.size
        when 'year'
          # Convert yearly data to monthly (divide by 12)
          total / (periods_data.size * 12)
        end
      end

      def generate_comparison(period_type, start_date, end_date)
        period_length = (end_date - start_date).to_i + 1

        # Calculate previous period
        previous_start = start_date - period_length.days
        previous_end = start_date - 1.day

        previous_transactions = current_user.financial_transactions
                                .where(date: previous_start..previous_end)

        previous_income = previous_transactions.income.sum(:amount)
        previous_expenses = previous_transactions.expense.sum(:amount).abs

        # Calculate same period last year
        last_year_start = start_date - 1.year
        last_year_end = end_date - 1.year

        last_year_transactions = current_user.financial_transactions
                                .where(date: last_year_start..last_year_end)

        last_year_income = last_year_transactions.income.sum(:amount)
        last_year_expenses = last_year_transactions.expense.sum(:amount).abs

        # Current period totals for comparison
        current_income = current_user.financial_transactions
                        .where(date: start_date..end_date)
                        .income.sum(:amount)
        current_expenses = current_user.financial_transactions
                          .where(date: start_date..end_date)
                          .expense.sum(:amount).abs

        # Create comparison data
        {
          previous_period: {
            start_date: previous_start,
            end_date: previous_end,
            income: {
              amount: previous_income,
              difference: current_income - previous_income,
              percentage_change: previous_income > 0 ?
                               ((current_income - previous_income) / previous_income * 100).round(2) : 0
            },
            expenses: {
              amount: previous_expenses,
              difference: current_expenses - previous_expenses,
              percentage_change: previous_expenses > 0 ?
                               ((current_expenses - previous_expenses) / previous_expenses * 100).round(2) : 0
            }
          },
          same_period_last_year: {
            start_date: last_year_start,
            end_date: last_year_end,
            income: {
              amount: last_year_income,
              difference: current_income - last_year_income,
              percentage_change: last_year_income > 0 ?
                               ((current_income - last_year_income) / last_year_income * 100).round(2) : 0
            },
            expenses: {
              amount: last_year_expenses,
              difference: current_expenses - last_year_expenses,
              percentage_change: last_year_expenses > 0 ?
                               ((current_expenses - last_year_expenses) / last_year_expenses * 100).round(2) : 0
            }
          }
        }
      end
    end
  end
end
