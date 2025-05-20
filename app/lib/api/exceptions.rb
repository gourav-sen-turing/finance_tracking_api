module API
  # Authentication Errors
  class NotAuthenticatedError < StandardError; end

  # Rate Limiting Errors
  class RateLimitExceededError < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("Rate limit exceeded. Retry after #{retry_after} seconds.")
    end
  end

  # Business Logic Errors
  class InsufficientFundsError < StandardError
    attr_reader :account_id, :required_amount, :available_amount

    def initialize(account_id, required_amount, available_amount)
      @account_id = account_id
      @required_amount = required_amount
      @available_amount = available_amount
      super("Insufficient funds in account ##{account_id}")
    end
  end

  # Add more custom exceptions for your finance application as needed
end
