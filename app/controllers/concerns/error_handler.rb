module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
    # If using Pundit for authorization
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
    # Custom exceptions
    rescue_from API::NotAuthenticatedError, with: :handle_unauthenticated
    rescue_from API::RateLimitExceededError, with: :handle_rate_limit_exceeded
  end

  private

  def handle_insufficient_funds(exception)
    error_response(
      status: 422,
      code: "INSUFFICIENT_FUNDS",
      message: exception.message,
      details: {
        account_id: exception.account_id,
        required_amount: exception.required_amount,
        available_amount: exception.available_amount
      }
    )
  end

  def handle_standard_error(exception)
    # Log the error with detailed information for debugging
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    # In production, don't expose internal error details to clients
    if Rails.env.production?
      error_response(
        status: 500,
        code: "INTERNAL_SERVER_ERROR",
        message: "An unexpected error occurred",
        details: nil
      )
    else
      # In development, include more details for debugging
      error_response(
        status: 500,
        code: "INTERNAL_SERVER_ERROR",
        message: exception.message,
        details: { backtrace: exception.backtrace[0..5] }
      )
    end
  end

  def handle_record_not_found(exception)
    error_response(
      status: 404,
      code: "RESOURCE_NOT_FOUND",
      message: "The requested resource could not be found",
      details: {
        resource: exception.model,
        field: exception.primary_key,
        value: exception.id
      }
    )
  end

  def handle_record_invalid(exception)
    errors = exception.record.errors.map do |error|
      {
        field: error.attribute,
        code: error_code_for_validation_error(error.attribute, error.type),
        message: error.message
      }
    end

    error_response(
      status: 422,
      code: "VALIDATION_ERROR",
      message: "Validation failed for the submitted resource",
      details: errors
    )
  end

  def handle_parameter_missing(exception)
    error_response(
      status: 400,
      code: "MISSING_PARAMETER",
      message: exception.message,
      details: {
        parameter: exception.param
      }
    )
  end

  def handle_record_not_unique(exception)
    # Extract the field name from the error message if possible
    field = extract_field_from_uniqueness_error(exception)

    error_response(
      status: 422,
      code: "RECORD_NOT_UNIQUE",
      message: "A record with the provided values already exists",
      details: {
        field: field
      }
    )
  end

  def handle_unauthorized(exception)
    error_response(
      status: 403,
      code: "FORBIDDEN",
      message: "You don't have permission to perform this action",
      details: {
        policy: exception.policy.class.to_s,
        query: exception.query
      }
    )
  end

  def handle_unauthenticated(_exception)
    error_response(
      status: 401,
      code: "UNAUTHORIZED",
      message: "Authentication is required to access this resource",
      details: nil
    )
  end

  def handle_rate_limit_exceeded(exception)
    error_response(
      status: 429,
      code: "RATE_LIMIT_EXCEEDED",
      message: "You have exceeded the allowed number of requests",
      details: {
        retry_after: exception.retry_after
      }
    )
  end

  def error_response(status:, code:, message:, details:)
    # Always include the request ID for tracking
    request_id = request.request_id || request.headers['X-Request-ID'] || SecureRandom.uuid

    error_body = {
      error: {
        status: status,
        code: code,
        message: message,
        request_id: request_id
      }
    }

    error_body[:error][:details] = details if details.present?

    # Log the error response in a structured way
    Rails.logger.info("API Error: #{status} #{code} - #{message} - Request ID: #{request_id}")

    render json: error_body, status: status
  end

  # Helper methods for standardizing error codes

  def error_code_for_validation_error(attribute, type)
    # Map Rails validation error types to your API error codes
    code_mapping = {
      blank: "BLANK",
      taken: "TAKEN",
      invalid: "INVALID",
      inclusion: "NOT_INCLUDED",
      exclusion: "EXCLUDED",
      too_short: "TOO_SHORT",
      too_long: "TOO_LONG",
      greater_than: "TOO_SMALL",
      less_than: "TOO_LARGE",
      not_a_number: "NOT_A_NUMBER"
    }

    # Fallback to a generic error code
    code_mapping[type] || "INVALID"
  end

  def extract_field_from_uniqueness_error(exception)
    # Extract field name from error message if possible
    message = exception.message
    match = message.match(/duplicate\s+key.*\(([^)]+)\)/)
    match ? match[1] : "unknown"
  end
end
