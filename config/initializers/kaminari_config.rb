Kaminari.configure do |config|
  config.default_per_page = 20       # Default number of items per page
  config.max_per_page = 100          # Maximum number of items per page
  config.window = 2                  # Number of pages to show around the current page in page navigation
  config.outer_window = 0            # Number of pages to show at the beginning and end of page navigation
  config.left = 0                    # Number of pages to show before the current page
  config.right = 0                   # Number of pages to show after the current page
  config.page_method_name = :page    # The method name for fetching the current page
  config.param_name = :page          # The parameter name for specifying the page in the URL
end
