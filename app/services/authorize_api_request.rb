class AuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  # Service entry point - return valid user object
  def call
    {
      result: user
    }
  end

  private

  attr_reader :headers

  def user
    # Check if user is in the database
    @user ||= User.find(decoded_auth_token[:user_id]) if decoded_auth_token
    # Handle user not found
    raise(ExceptionHandler::InvalidToken, "Invalid token") unless @user
    @user
  end

  # Decode authentication token
  def decoded_auth_token
    begin
      @decoded_auth_token ||= JsonWebToken.decode(http_auth_header)
    rescue JWT::ExpiredSignature
      Rails.logger.error "Token expired"
      raise ExceptionHandler::ExpiredSignature, "Token has expired"
    rescue JWT::DecodeError => e
      Rails.logger.error "Decode error: #{e.message}"
      raise ExceptionHandler::InvalidToken, e.message
    end
  end

  # Check for token in 'Authorization' header
  def http_auth_header
    if headers['Authorization'].present?
      auth_header = headers['Authorization']
      Rails.logger.debug "Processing Authorization header: #{auth_header}"

      if auth_header.start_with?('Bearer ')
        token = auth_header.split(' ').last
        if TokenBlacklist.blacklisted?(token)
          raise(ExceptionHandler::InvalidToken, "Token has been revoked")
        end
        return token
      else
        Rails.logger.error "Malformed Authorization header: #{auth_header}"
        raise(ExceptionHandler::InvalidToken, "Token format invalid")
      end
    end

    Rails.logger.error "Missing Authorization header"
    raise(ExceptionHandler::MissingToken, "Missing token")
  end
end

token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxMywiZXhwIjoxNzQ2MTgzNzA5fQ.YBSxEPizSzEl2A9MRftsTF0AvNzpBv15VgTX0mASFxA"
begin
  decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
  puts "Token decoded successfully: #{decoded.inspect}"
rescue JWT::DecodeError => e
  puts "Decoding error: #{e.message}"
rescue JWT::ExpiredSignature => e
  puts "Token expired: #{e.message}"
end
