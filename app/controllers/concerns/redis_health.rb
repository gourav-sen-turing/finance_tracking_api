module RedisHealth
  extend ActiveSupport::Concern

  included do
    rescue_from Redis::CannotConnectError do |e|
      Rails.logger.error "Redis connection error: #{e.message}"
      # Fallback behavior when Redis is down
      render json: { error: 'Service temporarily unavailable' }, status: :service_unavailable
    end
  end
end
