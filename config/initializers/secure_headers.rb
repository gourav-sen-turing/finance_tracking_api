SecureHeaders::Configuration.default do |config|
  # Enable HSTS with a 1 year max-age
  config.hsts = "max-age=31536000; includeSubDomains"

  # Prevent MIME type sniffing
  config.x_content_type_options = "nosniff"

  # Prevent your site from being embedded in iframes
  config.x_frame_options = "DENY"

  # Enable XSS protection
  config.x_xss_protection = "1; mode=block"

  # Control referrer information
  config.referrer_policy = "strict-origin-when-cross-origin"

  # Control browser features
  config.permissions_policy = {
    camera: [],
    microphone: [],
    geolocation: []
  }

  # Restrict Flash and PDF cross-domain policies
  config.x_permitted_cross_domain_policies = "none"

  # Content Security Policy for APIs
  config.csp = {
    default_src: %w('none'),
    frame_ancestors: %w('none'),
    form_action: %w('self')
  }
end
