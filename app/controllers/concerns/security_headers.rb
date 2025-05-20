module SecurityHeaders
  extend ActiveSupport::Concern

  included do
    before_action :set_security_headers
  end

  def set_security_headers
    # Base security headers for all responses
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
    response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'

    # Content Security Policy for API
    response.headers['Content-Security-Policy'] = "default-src 'none'; " \
                                                 "frame-ancestors 'none'; " \
                                                 "form-action 'self'"
  end
end
