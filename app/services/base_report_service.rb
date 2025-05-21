module Reports
  class BaseReportService
    attr_reader :user, :params, :start_date, :end_date

    def initialize(user, params = {})
      @user = user
      @params = params
      @start_date, @end_date = extract_date_range
    end

    def generate
      raise NotImplementedError, "Subclasses must implement the generate method"
    end

    def cached_generate
      cache_key = generate_cache_key

      Rails.cache.fetch(cache_key, expires_in: cache_expiration) do
        generate
      end
    end

    protected

    def extract_date_range
      DateRangeService.new(params).call
    end

    def financial_transactions
      @financial_transactions ||= begin
        scope = user.financial_transactions.where(date: start_date..end_date)
        # Exclude split parent transactions by default for accurate calculations
        scope.where.not(id: scope.where(is_split: true).select(:id))
      end
    end

    def income_transactions
      @income_transactions ||= financial_transactions.income
    end

    def expense_transactions
      @expense_transactions ||= financial_transactions.expense
    end

    def categories
      @categories ||= user.categories
    end

    def calculate_percentage(part, whole)
      return 0 if whole.nil? || whole.zero?
      ((part.to_f / whole) * 100).round(2)
    end

    def calculate_change_percentage(current, previous)
      return nil if previous.nil? || previous.zero?
      ((current - previous) / previous.abs * 100).round(2)
    end

    def generate_cache_key
      components = [
        "report",
        self.class.name.demodulize.underscore,
        user.id,
        Digest::MD5.hexdigest(params.to_s),
        user.financial_transactions.where(date: start_date..end_date).maximum(:updated_at).to_i
      ]
      components.join(":")
    end

    def cache_expiration
      12.hours
    end
  end
end
