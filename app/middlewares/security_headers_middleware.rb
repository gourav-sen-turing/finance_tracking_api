class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Process the request
    status, headers, response = @app.call(env)

    # Get request information
    request = ActionDispatch::Request.new(env)
    path = request.path

    # Skip for asset paths
    unless path.start_with?('/assets/')
      # Add security headers
      add_security_headers!(headers, path)
    end

    [status, headers, response]
  end

  private

  def add_security_headers!(headers, path)
    # Base security headers for all responses
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=(), payment=()'
    headers['X-Permitted-Cross-Domain-Policies'] = 'none'

    # Only add HSTS in production
    if Rails.env.production?
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end

    # Path-specific headers
    if path.start_with?('/api/v1/financial_transactions', '/api/v1/transfers')
      # Sensitive financial endpoints - strict caching controls
      headers['Cache-Control'] = 'no-store, max-age=0, must-revalidate'
      headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'; form-action 'self'"
    elsif path.start_with?('/api/v1/reports/download')
      # Downloadable content
      headers['Cache-Control'] = 'private, max-age=0, must-revalidate'
      # No CSP for downloads
    elsif path.start_with?('/api/v1/public')
      # Public API endpoints
      headers['Cache-Control'] = 'public, max-age=1800'
      headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'"
    else
      # Default API endpoints
      headers['Cache-Control'] = 'no-store, max-age=0, must-revalidate'
      headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'; form-action 'self'"
    end
  end
end
