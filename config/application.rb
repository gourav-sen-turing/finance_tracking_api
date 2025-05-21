require_relative "boot"
require_relative '../app/middlewares/security_headers_middleware'
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FinanceTrackerApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.autoload_paths << Rails.root.join('app', 'lib')
    config.eager_load_paths << Rails.root.join('app', 'lib')
    config.autoload_paths << Rails.root.join('app', 'middlewares')

    # Add middleware for rate limiting
    # config.middleware.use Rack::Attack

    # Add security headers middleware
    # Move this line AFTER the autoload configuration
    config.middleware.use SecurityHeadersMiddleware

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.action_dispatch.default_headers = {
      'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
      'X-Content-Type-Options' => 'nosniff',
      'X-Frame-Options' => 'DENY',
      'X-XSS-Protection' => '1; mode=block',
      'Referrer-Policy' => 'strict-origin-when-cross-origin',
      'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
      'X-Permitted-Cross-Domain-Policies' => 'none',
      'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'; form-action 'self'"
    }
  end
end
