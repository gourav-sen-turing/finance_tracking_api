class JwtHandler
  # Generate this with: SecureRandom.hex(32)
  SECRET_KEY = '4f74c5bc41ef930f534ad4ed480102c3d0b0bd2aa380d90cc604b61c5c89973f'

  class << self
    def encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, SECRET_KEY, 'HS256')
    end

    def decode(token)
      JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
    rescue JWT::DecodeError => e
      nil
    end
  end
end
