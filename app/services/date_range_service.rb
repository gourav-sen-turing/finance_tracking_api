module Reports
  class DateRangeService
    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    def call
      if params[:start_date].present? && params[:end_date].present?
        # Custom date range
        [parse_date(params[:start_date]), parse_date(params[:end_date])]
      elsif params[:period].present?
        # Predefined period
        case params[:period]
        when 'week'
          [Date.current.beginning_of_week, Date.current.end_of_week]
        when 'month'
          [Date.current.beginning_of_month, Date.current.end_of_month]
        when 'quarter'
          [Date.current.beginning_of_quarter, Date.current.end_of_quarter]
        when 'year'
          [Date.current.beginning_of_year, Date.current.end_of_year]
        when 'last_month'
          last_month = Date.current - 1.month
          [last_month.beginning_of_month, last_month.end_of_month]
        when 'last_quarter'
          last_quarter = Date.current - 3.months
          [last_quarter.beginning_of_quarter, last_quarter.end_of_quarter]
        when 'last_year'
          last_year = Date.current - 1.year
          [last_year.beginning_of_year, last_year.end_of_year]
        when 'all'
          [user.financial_transactions.minimum(:date) || Date.current - 1.year, Date.current]
        else
          default_date_range
        end
      elsif params[:year].present? && params[:month].present?
        # Specific month/year
        year = params[:year].to_i
        month = params[:month].to_i
        [Date.new(year, month, 1), Date.new(year, month, -1)]
      else
        # Default to current month if no parameters provided
        default_date_range
      end
    end

    private

    def parse_date(date_str)
      Date.parse(date_str)
    rescue ArgumentError, TypeError
      Date.current
    end

    def default_date_range
      [Date.current.beginning_of_month, Date.current.end_of_month]
    end
  end
end
