module ExceptionHandler
  # Include to extend ActiveSupport
  extend ActiveSupport::Concern

  # Define custom error classes
  class AuthenticationError < StandardError; end
  class MissingToken < StandardError; end
  class InvalidToken < StandardError; end
  class ExpiredSignature < StandardError; end

  included do
    # Define custom handlers for exceptions
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity_response
    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized_response
    rescue_from ExceptionHandler::MissingToken, with: :unauthorized_response
    rescue_from ExceptionHandler::InvalidToken, with: :unauthorized_response
    rescue_from ExceptionHandler::ExpiredSignature, with: :unauthorized_response

    # Handle record not found errors
    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: {
        error: e.message
      }, status: :not_found
    end
  end

  private

  # Return 422 status - unprocessable entity
  def unprocessable_entity_response(error)
    render json: {
      error: error.message
    }, status: :unprocessable_entity
  end

  # Return 401 status - unauthorized
  def unauthorized_response(error)
    render json: {
      error: error.message
    }, status: :unauthorized
  end
end
