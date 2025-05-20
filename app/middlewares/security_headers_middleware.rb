class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Get information about the request
    request = ActionDispatch::Request.new(env)
    path = request.path

    # Process the request
    status, headers, response = @app.call(env)

    # Skip security headers for certain paths or file types
    if skip_security_headers?(path)
      return [status, headers, response]
    end

    # Add appropriate headers based on path
    add_security_headers!(headers, path)

    [status, headers, response]
  end

  private

  def skip_security_headers?(path)
    # Skip for public assets, health check, etc.
    path.start_with?('/assets/', '/health', '/public/') ||
      path.match?(/\.(jpg|jpeg|png|gif|svg|css|js)$/)
  end

  def add_security_headers!(headers, path)
    # Base headers for all responses
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['X-Permitted-Cross-Domain-Policies'] = 'none'

    # Only add HSTS header in production and for HTTPS requests
    if Rails.env.production? && request_over_ssl?(headers)
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end

    # Path-specific header customization
    if path.start_with?('/api/v1/reports/download')
      # Downloadable content headers
      headers['Cache-Control'] = 'private, max-age=0, must-revalidate'
      # Remove CSP for downloadable content
      headers.delete('Content-Security-Policy')
    elsif path.start_with?('/api/v1/public')
      # Public API endpoints
      headers['Cache-Control'] = 'public, max-age=1800'
      headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'"
    else
      # Standard API endpoints
      headers['Cache-Control'] = 'no-store, max-age=0, must-revalidate'
      headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'; form-action 'self'"
    end

    # Add feature policy
    headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=(), payment=()'
  end

  def request_over_ssl?(headers)
    headers['X-Forwarded-Proto'] == 'https' || @request.ssl?
  end
end
