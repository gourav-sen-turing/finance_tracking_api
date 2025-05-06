class JsonWebToken
  SECRET_KEY = Rails.application.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    # Add JWT ID for blacklisting purposes
    payload[:jti] ||= SecureRandom.uuid

    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
    HashWithIndifferentAccess.new body
  rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end
end
