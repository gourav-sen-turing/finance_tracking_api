module DateRangeReportable
  extend ActiveSupport::Concern

  included do
    before_action :parse_date_range, only: [:index, :summary, :spending_breakdown, :income_expense_analysis]
  end

  private

  def parse_date_range
    # Handle specific date range parameters
    if params[:start_date].present? && params[:end_date].present?
      begin
        @start_date = Date.parse(params[:start_date])
        @end_date = Date.parse(params[:end_date])

        # Validate date range
        validate_date_range(@start_date, @end_date)
      rescue ArgumentError => e
        render json: { error: "Invalid date format", details: e.message }, status: :bad_request
        return
      end
    # Handle preset range parameters
    elsif params[:range].present?
      set_preset_date_range(params[:range])
    # Default to current month if no range specified
    else
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
      @date_range_type = 'current_month'
    end

    # Add date range to response metadata
    @date_range_metadata = {
      start_date: @start_date,
      end_date: @end_date,
      range_type: @date_range_type || 'custom',
      days_in_range: (@end_date - @start_date).to_i + 1
    }
  end

  def determine_grouping_level
    days_in_range = (@end_date - @start_date).to_i + 1

    if days_in_range <= 1
      :hourly       # For single day reports, group by hour
    elsif days_in_range <= 31
      :daily        # For up to a month, group by day
    elsif days_in_range <= 92
      :weekly       # For up to three months, group by week
    elsif days_in_range <= 366
      :monthly      # For up to a year, group by month
    elsif days_in_range <= 1830  # ~5 years
      :quarterly    # For up to five years, group by quarter
    else
      :yearly       # For very large ranges, group by year
    end
  end

  def set_preset_date_range(range_type)
    case range_type
    when 'today'
      @start_date = Date.current
      @end_date = Date.current
    when 'yesterday'
      @start_date = Date.current - 1.day
      @end_date = Date.current - 1.day
    when 'current_week'
      @start_date = Date.current.beginning_of_week
      @end_date = Date.current.end_of_week
    when 'current_month'
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    when 'previous_month'
      @start_date = (Date.current - 1.month).beginning_of_month
      @end_date = (Date.current - 1.month).end_of_month
    when 'last_30_days'
      @start_date = Date.current - 30.days
      @end_date = Date.current
    when 'last_90_days'
      @start_date = Date.current - 90.days
      @end_date = Date.current
    when 'current_quarter'
      @start_date = Date.current.beginning_of_quarter
      @end_date = Date.current.end_of_quarter
    when 'previous_quarter'
      @start_date = (Date.current - 3.months).beginning_of_quarter
      @end_date = (Date.current - 3.months).end_of_quarter
    when 'year_to_date'
      @start_date = Date.current.beginning_of_year
      @end_date = Date.current
    when 'previous_year'
      @start_date = Date.current.prev_year.beginning_of_year
      @end_date = Date.current.prev_year.end_of_year
    when 'last_12_months'
      @start_date = Date.current - 1.year
      @end_date = Date.current
    when 'all_time'
      @start_date = current_user.financial_transactions.minimum(:date) || Date.current.beginning_of_year
      @end_date = Date.current
    else
      # Default to current month for unrecognized range types
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
      range_type = 'current_month'
    end

    @date_range_type = range_type
  end

  def validate_date_range(start_date, end_date)
    # Check that start date is before or equal to end date
    if start_date > end_date
      render json: {
        error: "Invalid date range",
        details: "Start date must be before or equal to end date"
      }, status: :bad_request
      return false
    end

    # Check that date range isn't too large (optional, to prevent performance issues)
    if (end_date - start_date).to_i > 3650 # ~10 years
      render json: {
        error: "Invalid date range",
        details: "Date range too large, maximum range is 10 years"
      }, status: :bad_request
      return false
    end

    # Check that start date isn't before user account creation (optional)
    if start_date < current_user.created_at.to_date
      render json: {
        error: "Invalid date range",
        details: "Start date cannot be before account creation date (#{current_user.created_at.to_date})"
      }, status: :bad_request
      return false
    end

    true
  end
end
