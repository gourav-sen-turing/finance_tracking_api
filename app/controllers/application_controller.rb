class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def not_found(exception)
    render json: {
      errors: [{
        status: '404',
        title: 'Not Found',
        detail: exception.message
      }]
    }, status: :not_found
  end

  def parameter_missing(exception)
    render json: {
      errors: [{
        status: '400',
        title: 'Bad Request',
        detail: exception.message
      }]
    }, status: :bad_request
  end

  def authenticate_user
    byebug
    header = request.headers['Authorization']
    if header.present?
      token = header.split(' ').last
      begin
        @decoded = JsonWebToken.decode(token)
        @current_user = User.find(@decoded[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'User not found' }, status: :unauthorized
      rescue JWT::ExpiredSignature
        render json: { errors: 'Token has expired, please log in again' }, status: :unauthorized
      rescue JWT::DecodeError, JWT::VerificationError
        render json: { errors: 'Invalid token' }, status: :unauthorized
      rescue StandardError => e
        Rails.logger.error("Authentication error: #{e.class} - #{e.message}")
        render json: { errors: 'Authentication error' }, status: :unauthorized
      end
    else
      render json: { errors: 'Missing token' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  # Add a method to help with debugging
  def debug_request_headers
    request.headers.each do |key, value|
      Rails.logger.info "Header: #{key} = #{value}" unless key.starts_with?('rack.')
    end
  end
end
