module ApiResponse
  extend ActiveSupport::Concern

  def render_success(data, status = :ok)
    render json: data, status: status
  end

  def render_error(message, status = :unprocessable_entity, errors = nil)
    response = {
      error: {
        message: message
      }
    }
    response[:error][:errors] = errors if errors.present?

    render json: response, status: status
  end

  def render_not_found(resource = 'Record')
    render_error("#{resource} not found", :not_found)
  end

  def render_unauthorized(message = 'Unauthorized')
    render_error(message, :unauthorized)
  end

  def render_validation_error(model)
    errors = model.errors.map { |error|
      {
        field: error.attribute,
        message: error.message
      }
    }
    render_error("Validation failed", :unprocessable_entity, errors)
  end
end
