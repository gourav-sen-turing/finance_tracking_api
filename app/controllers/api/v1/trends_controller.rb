module Api
  module V1
    class TrendsController < ApplicationController
      include DateRangeReportable
      before_action :authenticate_user!

      # GET /api/v1/trends/spending
      def spending
        # Get timeframe parameters
        timeframe = params[:timeframe] || 'monthly'
        periods = params[:periods]&.to_i || 12  # Default to 12 periods
        end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

        # Determine period type and generate periods
        case timeframe
        when 'weekly'
          period_data = generate_weekly_periods(end_date, periods)
        when 'monthly'
          period_data = generate_monthly_periods(end_date, periods)
        when 'quarterly'
          period_data = generate_quarterly_periods(end_date, periods)
        when 'yearly'
          period_data = generate_yearly_periods(end_date, periods)
        else
          render json: { error: 'Invalid timeframe parameter' }, status: :bad_request
          return
        end

        # Calculate spending for each period
        spending_by_period = calculate_spending_by_period(period_data)

        # Calculate category spending for trend analysis
        category_trends = calculate_category_trends(period_data, 3)  # Top 3 categories

        # Detect patterns in the data
        spending_patterns = detect_spending_patterns(spending_by_period)

        # Calculate moving averages for smoothed trend
        moving_averages = calculate_moving_averages(spending_by_period)

        # Calculate seasonality if we have enough data
        seasonality = calculate_seasonality(spending_by_period) if period_data.size >= 12

        # Calculate forecast if requested
        forecast = params[:include_forecast] == 'true' ?
                 generate_spending_forecast(spending_by_period, 3) : nil  # Forecast next 3 periods

        # Determine significant periods
        significant_periods = identify_significant_periods(spending_by_period)

        # Prepare response
        response = {
          timeframe: timeframe,
          periods: spending_by_period,
          analysis: {
            trend_direction: spending_patterns[:direction],
            trend_strength: spending_patterns[:strength],
            trend_description: spending_patterns[:description],
            year_over_year_change: calculate_year_over_year_change(spending_by_period),
            average_growth_rate: calculate_average_growth_rate(spending_by_period)
          },
          moving_averages: moving_averages,
          category_trends: category_trends,
          significant_periods: significant_periods
        }

        # Add conditional sections
        response[:seasonality] = seasonality if seasonality
        response[:forecast] = forecast if forecast

        render json: response
      end

      # GET /api/v1/trends/income
      def income
        # Similar implementation to spending trends
        # ...
      end

      # GET /api/v1/trends/savings_rate
      def savings_rate
        # Implement savings rate trend analysis
        # ...
      end

      # GET /api/v1/trends/categories/:id
      def category_trend
        category = current_user.categories.find(params[:id])
        timeframe = params[:timeframe] || 'monthly'
        periods = params[:periods]&.to_i || 12

        # Generate periods and analyze category spending
        # ...

        render json: {
          category: {
            id: category.id,
            name: category.name
          },
          # Trend data...
        }
      end

      # GET /api/v1/trends/budget_adherence
      def budget_adherence
        # Analyze budget adherence trends over time
        # ...
      end

      private

      def generate_monthly_periods(end_date, count)
        periods = []
        count.times do |i|
          current_date = end_date.prev_month(i)
          period_start = current_date.beginning_of_month
          period_end = current_date.end_of_month

          periods.unshift({
            period_name: current_date.strftime("%b %Y"),
            start_date: period_start,
            end_date: period_end
          })
        end
        periods
      end

      def generate_weekly_periods(end_date, count)
        # Implementation for weekly periods
        # ...
      end

      def generate_quarterly_periods(end_date, count)
        periods = []

        count.times do |i|
          # Calculate the current quarter date
          months_ago = i * 3
          current_date = end_date.prev_month(months_ago)
          quarter = ((current_date.month - 1) / 3) + 1
          quarter_start = Date.new(current_date.year, (quarter - 1) * 3 + 1, 1)
          quarter_end = quarter_start.end_of_month.next_month.next_month

          periods.unshift({
            period_name: "Q#{quarter} #{current_date.year}",
            start_date: quarter_start,
            end_date: quarter_end
          })
        end

        periods
      end

      def generate_yearly_periods(end_date, count)
        periods = []

        count.times do |i|
          year = end_date.year - i
          periods.unshift({
            period_name: year.to_s,
            start_date: Date.new(year, 1, 1),
            end_date: Date.new(year, 12, 31)
          })
        end

        periods
      end

      def calculate_spending_by_period(periods)
        periods.map do |period|
          # Get transactions for this period
          transactions = current_user.financial_transactions
                                   .expense
                                   .where(date: period[:start_date]..period[:end_date])

          total_amount = transactions.sum(:amount).abs
          transaction_count = transactions.count

          period.merge({
            total_amount: total_amount,
            transaction_count: transaction_count,
            average_transaction: transaction_count > 0 ? (total_amount / transaction_count).round(2) : 0
          })
        end
      end

      def calculate_category_trends(periods, top_count)
        # Get all categories used in these periods
        start_date = periods.first[:start_date]
        end_date = periods.last[:end_date]

        # Find categories with transactions during the overall period
        category_ids = current_user.financial_transactions
                                 .expense
                                 .where(date: start_date..end_date)
                                 .pluck(:category_id)
                                 .uniq

        # Calculate trends for each category
        category_data = []

        category_ids.each do |cat_id|
          category = current_user.categories.find(cat_id)

          # Calculate spending for each period
          period_spending = periods.map do |period|
            amount = current_user.financial_transactions
                               .expense
                               .where(date: period[:start_date]..period[:end_date], category_id: cat_id)
                               .sum(:amount).abs

            {
              period_name: period[:period_name],
              amount: amount
            }
          end

          # Calculate overall trend direction
          amounts = period_spending.map { |ps| ps[:amount] }
          trend = determine_trend_direction(amounts)

          # Calculate total and average
          total = amounts.sum
          avg = total / amounts.size

          category_data << {
            id: category.id,
            name: category.name,
            total_spending: total,
            average_per_period: avg,
            trend: trend,
            period_data: period_spending,
            growth_rate: calculate_average_growth_rate(period_spending)
          }
        end

        # Sort by total spending (descending)
        category_data.sort_by! { |cat| -cat[:total_spending] }

        # Return top N categories by spending
        category_data.first(top_count)
      end

      def detect_spending_patterns(periods)
        amounts = periods.map { |p| p[:total_amount] }

        # Calculate trend direction using linear regression
        trend_direction = determine_trend_direction(amounts)

        # Calculate seasonal index if we have enough data
        seasonal_index = amounts.size >= 12 ? calculate_seasonal_index(amounts) : nil

        # Calculate trend strength (R-squared value)
        trend_strength = calculate_trend_strength(amounts)

        # Generate natural language description
        description = generate_trend_description(trend_direction, trend_strength, seasonal_index)

        {
          direction: trend_direction,
          strength: trend_strength,
          description: description,
          seasonal_index: seasonal_index
        }
      end

      def calculate_moving_averages(periods)
        amounts = periods.map { |p| p[:total_amount] }

        # Calculate 3-period moving average
        ma3 = []
        (2...amounts.size).each do |i|
          ma3 << {
            period_name: periods[i][:period_name],
            amount: ((amounts[i-2] + amounts[i-1] + amounts[i]) / 3.0).round(2)
          }
        end

        # Calculate 6-period moving average if we have enough data
        ma6 = []
        if amounts.size >= 6
          (5...amounts.size).each do |i|
            ma6 << {
              period_name: periods[i][:period_name],
              amount: ((amounts[i-5] + amounts[i-4] + amounts[i-3] +
                      amounts[i-2] + amounts[i-1] + amounts[i]) / 6.0).round(2)
            }
          end
        end

        {
          three_period: ma3,
          six_period: ma6
        }
      end

      def calculate_seasonality(periods)
        # Only calculate seasonality for monthly data with at least 12 periods
        return nil unless periods.size >= 12 && periods.first[:period_name].include?(' ')

        # Group periods by month
        month_groups = periods.group_by { |p| Date.parse("1 #{p[:period_name]}").month }

        # Calculate average spending for each month
        monthly_averages = {}
        month_groups.each do |month, data|
          total = data.sum { |p| p[:total_amount] }
          avg = total / data.size
          monthly_averages[month] = avg
        end

        # Calculate overall average
        overall_avg = monthly_averages.values.sum / monthly_averages.size

        # Calculate seasonal indices
        seasonal_indices = {}
        monthly_averages.each do |month, avg|
          seasonal_indices[month] = ((avg / overall_avg) * 100).round(2)
        end

        # Identify high and low seasons
        high_months = seasonal_indices.select { |_, index| index > 110 }
                                    .sort_by { |_, index| -index }
                                    .map { |month, index| [Date::MONTHNAMES[month], index] }
                                    .to_h

        low_months = seasonal_indices.select { |_, index| index < 90 }
                                   .sort_by { |_, index| index }
                                   .map { |month, index| [Date::MONTHNAMES[month], index] }
                                   .to_h

        {
          indices: seasonal_indices.transform_keys { |k| Date::MONTHNAMES[k] },
          high_spending_months: high_months,
          low_spending_months: low_months,
          seasonality_strength: calculate_seasonality_strength(seasonal_indices.values)
        }
      end

      def generate_spending_forecast(periods, forecast_periods)
        amounts = periods.map { |p| p[:total_amount] }

        # Use simple or more complex forecasting methods based on data patterns
        forecasted_values = simple_forecast_method(amounts, forecast_periods)

        # Generate period names for forecasted periods
        last_period = periods.last
        forecast_period_names = generate_forecast_period_names(last_period, forecast_periods)

        forecast_period_names.zip(forecasted_values).map.with_index do |(name, value), i|
          {
            period_name: name,
            forecasted_amount: value.round(2),
            confidence_interval: calculate_forecast_confidence(amounts, i+1)
          }
        end
      end

      def simple_forecast_method(historical_values, periods_to_forecast)
        # Use simple exponential smoothing or more advanced methods
        # This is a simplified implementation

        # Get recent trend
        recent_values = historical_values.last(6)
        avg_change = 0

        (1...recent_values.size).each do |i|
          avg_change += (recent_values[i] - recent_values[i-1])
        end

        avg_change /= (recent_values.size - 1)
        last_value = historical_values.last

        # Forecast future values based on recent trend
        (1..periods_to_forecast).map do |i|
          last_value + (avg_change * i)
        end
      end

      def generate_forecast_period_names(last_period, count)
        # Generate period names based on the type of the last period
        period_name = last_period[:period_name]

        if period_name.include?(' ')  # Monthly (e.g., "Jan 2023")
          date = Date.parse("1 #{period_name}")
          (1..count).map do |i|
            date.next_month(i).strftime("%b %Y")
          end
        elsif period_name.start_with?('Q')  # Quarterly (e.g., "Q1 2023")
          quarter = period_name[1].to_i
          year = period_name[3..6].to_i

          (1..count).map do |i|
            new_quarter = ((quarter - 1 + i) % 4) + 1
            new_year = year + ((quarter - 1 + i) / 4)
            "Q#{new_quarter} #{new_year}"
          end
        else  # Yearly (e.g., "2023")
          year = period_name.to_i
          (1..count).map do |i|
            (year + i).to_s
          end
        end
      end

      def calculate_forecast_confidence(historical_values, periods_ahead)
        # Calculate forecast confidence intervals
        # Simplified implementation - more advanced methods would be better

        std_dev = calculate_standard_deviation(historical_values)
        error_margin = std_dev * Math.sqrt(periods_ahead) * 1.96  # 95% confidence

        # Return confidence interval as percentage
        (error_margin / historical_values.last * 100).round(1)
      end

      def calculate_standard_deviation(values)
        return 0 if values.empty?

        mean = values.sum / values.size.to_f
        sum_squared_differences = values.sum { |v| (v - mean)**2 }
        Math.sqrt(sum_squared_differences / values.size)
      end

      def identify_significant_periods(periods)
        # Find periods with unusual spending patterns
        amounts = periods.map { |p| p[:total_amount] }
        avg = amounts.sum / amounts.size.to_f
        std_dev = calculate_standard_deviation(amounts)

        significant = []

        periods.each_with_index do |period, i|
          amount = period[:total_amount]
          z_score = (amount - avg) / std_dev

          if z_score.abs > 1.5  # More than 1.5 standard deviations from mean
            significant << {
              period_name: period[:period_name],
              amount: amount,
              z_score: z_score.round(2),
              type: z_score > 0 ? "unusually_high" : "unusually_low",
              percent_difference: ((amount - avg) / avg * 100).round(2)
            }
          end
        end

        # Sort by absolute z-score (descending)
        significant.sort_by { |s| -s[:z_score].abs }
      end

      def calculate_year_over_year_change(periods)
        # Group periods by year
        period_by_year = {}

        periods.each do |period|
          year = if period[:period_name].include?(' ')  # Monthly/quarterly
                  period[:period_name].split(' ').last.to_i
                else  # Yearly
                  period[:period_name].to_i
                end

          period_by_year[year] ||= []
          period_by_year[year] << period
        end

        # Calculate total spending by year
        spending_by_year = {}
        period_by_year.each do |year, year_periods|
          spending_by_year[year] = year_periods.sum { |p| p[:total_amount] }
        end

        # Calculate year-over-year changes
        yoy_changes = []
        years = spending_by_year.keys.sort

        (1...years.size).each do |i|
          current_year = years[i]
          previous_year = years[i-1]

          current_spending = spending_by_year[current_year]
          previous_spending = spending_by_year[previous_year]

          change_percentage = calculate_percentage_change(current_spending, previous_spending)

          yoy_changes << {
            year: current_year,
            previous_year: previous_year,
            current_spending: current_spending,
            previous_spending: previous_spending,
            change_percentage: change_percentage,
            change_amount: current_spending - previous_spending
          }
        end

        yoy_changes
      end

      def calculate_average_growth_rate(periods)
        amounts = periods.map { |p| p[:total_amount] }
        return 0 if amounts.size < 2

        # Calculate period-over-period changes
        change_rates = []
        (1...amounts.size).each do |i|
          if amounts[i-1] > 0
            change_rate = (amounts[i] - amounts[i-1]) / amounts[i-1].to_f
            change_rates << change_rate
          end
        end

        return 0 if change_rates.empty?

        # Average growth rate as a percentage
        (change_rates.sum / change_rates.size * 100).round(2)
      end

      def calculate_trend_strength(values)
        return 0 if values.size < 3

        # Calculate R-squared value (coefficient of determination)
        x_values = (0...values.length).to_a

        # Linear regression calculations
        slope = calculate_linear_regression_slope(x_values, values)
        intercept = calculate_linear_regression_intercept(x_values, values, slope)

        # Calculate predicted values
        predicted = x_values.map { |x| slope * x + intercept }

        # Calculate total sum of squares and residual sum of squares
        mean = values.sum / values.size.to_f
        total_sum_squares = values.sum { |y| (y - mean)**2 }
        residual_sum_squares = values.zip(predicted).sum { |y, y_hat| (y - y_hat)**2 }

        # Calculate R-squared
        r_squared = 1 - (residual_sum_squares / total_sum_squares)

        # Return as percentage
        (r_squared * 100).round(2)
      end

      def calculate_linear_regression_intercept(x_values, y_values, slope)
        x_mean = x_values.sum / x_values.size.to_f
        y_mean = y_values.sum / y_values.size.to_f

        y_mean - (slope * x_mean)
      end

      def calculate_seasonality_strength(seasonal_indices)
        # Calculate variation in seasonal indices
        mean = seasonal_indices.sum / seasonal_indices.size.to_f
        variance = seasonal_indices.sum { |index| (index - 100)**2 } / seasonal_indices.size.to_f

        # Normalize to 0-100 scale
        strength = [variance / 500, 1].min * 100

        strength.round(1)
      end

      def generate_trend_description(direction, strength, seasonality)
        # Create natural language description based on trend analysis
        base_description = case direction
                          when "consistently_increasing"
                            "Your spending has been steadily increasing"
                          when "moderately_increasing"
                            "Your spending has been generally increasing, with some fluctuations"
                          when "stable"
                            "Your spending has remained relatively stable"
                          when "moderately_decreasing"
                            "Your spending has been generally decreasing, with some fluctuations"
                          when "consistently_decreasing"
                            "Your spending has been steadily decreasing"
                          else
                            "Your spending pattern shows no clear trend"
                          end

        # Add strength qualification
        strength_description = if strength > 80
                               "This trend is very consistent"
                             elsif strength > 60
                               "This trend is fairly consistent"
                             elsif strength > 40
                               "This trend shows moderate consistency"
                             elsif strength > 20
                               "This trend has significant variability"
                             else
                               "This trend has high variability"
                             end

        # Add seasonality if available
        seasonality_description = if seasonality && seasonality[:seasonality_strength] > 30
                                  high_months = seasonality[:high_spending_months].keys.first(2).join(" and ")
                                  "Your spending also shows seasonal patterns, with higher spending typically in #{high_months}"
                                else
                                  ""
                                end

        [base_description, strength_description, seasonality_description].reject(&:empty?).join(". ") + "."
      end
    end
  end
end
