require 'redis'
require 'redis/namespace'

redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  timeout: 1
}

# Create Redis connection
$redis = Redis.new(redis_config)

# Optional: Use namespaced Redis to isolate keys
$redis = Redis::Namespace.new('finance_tracker:auth', redis: $redis)
