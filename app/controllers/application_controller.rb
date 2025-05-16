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
    header = request.headers['Authorization']
    if header.present?
      token = header.split(' ').last
      begin
        @decoded = JwtHandler.decode(token)
        if @decoded
          @current_user = User.find(@decoded['user_id'])
        else
          render json: { error: 'Invalid token' }, status: :unauthorized
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :unauthorized
      end
    else
      render json: { error: 'Authorization header missing' }, status: :unauthorized
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
