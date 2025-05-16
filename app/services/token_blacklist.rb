class TokenBlacklist
  class << self
    # Add a token to the blacklist with expiry time from token
    def add(token)
      return false unless token.present?

      # Extract the token's expiry time
      begin
        payload = JsonWebToken.decode(token)
        exp_time = Time.at(payload[:exp]).to_i
        current_time = Time.now.to_i

        # Calculate remaining time until expiration (in seconds)
        ttl = [exp_time - current_time, 0].max

        # Generate a consistent key for this token
        jti = payload[:jti] || generate_token_fingerprint(token)

        # Add to blacklist with automatic expiry
        $redis.set("blacklist:#{jti}", 1, ex: ttl)
        return true
      rescue StandardError => e
        Rails.logger.error "Failed to blacklist token: #{e.message}"
        return false
      end
    end

    # Check if a token is blacklisted
    def blacklisted?(token)
      return false unless token.present?

      begin
        payload = JsonWebToken.decode(token)
        jti = payload[:jti] || generate_token_fingerprint(token)
        $redis.exists("blacklist:#{jti}") == 1
      rescue StandardError => e
        # If token cannot be decoded, consider it invalid
        Rails.logger.error "Failed to check blacklisted token: #{e.message}"
        true
      end
    end

    private

    # Generate consistent fingerprint for tokens without JTI claim
    def generate_token_fingerprint(token)
      Digest::SHA256.hexdigest(token)
    end
  end
end
