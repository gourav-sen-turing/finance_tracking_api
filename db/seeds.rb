  # db/seeds.rb
  # Seed data for Finance Tracker API

  puts "Cleaning the database..."
  # Destroy in correct order to respect dependencies
  Budget.destroy_all
  Transaction.destroy_all
  Category.destroy_all
  User.destroy_all

  puts "Creating users..."
  # Create 3 users with different profiles
  users = [
    {
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      # password: "password123",
      date_of_birth: Date.new(1985, 5, 15),
      phone: "555-123-4567",
      currency_preference: "USD",
      time_zone: "America/New_York"
    },
    {
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com",
      # password: "password123",
      date_of_birth: Date.new(1990, 8, 23),
      phone: "555-987-6543",
      currency_preference: "EUR",
      time_zone: "Europe/Paris"
    },
    {
      first_name: "Carlos",
      last_name: "Rodriguez",
      email: "carlos@example.com",
      # password: "password123",
      date_of_birth: Date.new(1978, 11, 3),
      phone: "555-456-7890",
      currency_preference: "MXN",
      time_zone: "America/Mexico_City"
    }
  ]

  created_users = users.map do |user_attrs|
    User.create!(user_attrs)
  end

  # Get references to our users for later use
  john = created_users[0]
  jane = created_users[1]
  carlos = created_users[2]

  puts "Creating default categories..."
  # Define system default categories (not associated with specific users)
  default_income_categories = [
    { name: "Salary", description: "Regular employment income", category_type: "income", color: "#4CAF50", icon: "work" },
    { name: "Freelance", description: "Income from freelance work", category_type: "income", color: "#2196F3", icon: "computer" },
    { name: "Investments", description: "Income from investments", category_type: "income", color: "#9C27B0", icon: "trending_up" },
    { name: "Gifts", description: "Money received as gifts", category_type: "income", color: "#E91E63", icon: "redeem" }
  ]

  default_expense_categories = [
    { name: "Housing", description: "Rent or mortgage payments", category_type: "expense", color: "#F44336", icon: "home" },
    { name: "Groceries", description: "Food and household items", category_type: "expense", color: "#FF9800", icon: "local_grocery_store" },
    { name: "Transportation", description: "Car, public transport, etc.", category_type: "expense", color: "#3F51B5", icon: "directions_car" },
    { name: "Utilities", description: "Electric, water, gas, internet", category_type: "expense", color: "#009688", icon: "power" },
    { name: "Entertainment", description: "Movies, games, etc.", category_type: "expense", color: "#673AB7", icon: "movie" },
    { name: "Dining Out", description: "Restaurants and takeout", category_type: "expense", color: "#FFC107", icon: "restaurant" },
    { name: "Healthcare", description: "Medical expenses", category_type: "expense", color: "#00BCD4", icon: "local_hospital" },
    { name: "Education", description: "Tuition, books, courses", category_type: "expense", color: "#795548", icon: "school" },
    { name: "Shopping", description: "Clothing, electronics, etc.", category_type: "expense", color: "#607D8B", icon: "shopping_bag" }
  ]

  # Create system default categories (is_default: true, no user association)
  default_income_categories.each do |cat|
    Category.create!(**cat, is_default: true)
  end

  default_expense_categories.each do |cat|
    Category.create!(**cat, is_default: true)
  end

  puts "Creating user-specific categories..."
  # Create user-specific categories
  john_income_cats = [
    { name: "Bonus", description: "Annual performance bonus", category_type: "income", color: "#8BC34A", icon: "stars", user: john }
  ]

  john_expense_cats = [
    { name: "Gym", description: "Gym membership and gear", category_type: "expense", color: "#FF5722", icon: "fitness_center", user: john },
    { name: "Dog Care", description: "Pet food and vet visits", category_type: "expense", color: "#795548", icon: "pets", user: john }
  ]

  jane_income_cats = [
    { name: "Rental Income", description: "Income from rental property", category_type: "income", color: "#CDDC39", icon: "apartment", user: jane }
  ]

  jane_expense_cats = [
    { name: "Art Supplies", description: "Painting materials and tools", category_type: "expense", color: "#9E9E9E", icon: "palette", user: jane }
  ]

  # Create all user-specific categories
  [john_income_cats, john_expense_cats, jane_income_cats, jane_expense_cats].each do |category_group|
    category_group.each do |cat|
      Category.create!(**cat)
    end
  end

  # Create subcategories for transportation
  transport_cat = Category.find_by(name: "Transportation", is_default: true)

  transport_subcats = [
    { name: "Fuel", description: "Gasoline and fuel expenses", category_type: "expense", color: "#3F51B5", icon: "local_gas_station" },
    { name: "Public Transit", description: "Bus, subway, train", category_type: "expense", color: "#3F51B5", icon: "directions_bus" },
    { name: "Car Maintenance", description: "Repairs and servicing", category_type: "expense", color: "#3F51B5", icon: "build" }
  ]

  transport_subcats.each do |subcat|
    Category.create!(**subcat, is_default: true, parent_category: transport_cat)
  end

  # Get all income and expense categories for reference
  all_income_categories = Category.where(category_type: "income")
  all_expense_categories = Category.where(category_type: "expense")
  john_available_income_cats = all_income_categories.where(user: [nil, john])
  john_available_expense_cats = all_expense_categories.where(user: [nil, john])
  jane_available_income_cats = all_income_categories.where(user: [nil, jane])
  jane_available_expense_cats = all_expense_categories.where(user: [nil, jane])

  puts "Creating transactions..."
  # Create transactions for past 3 months
  def create_transactions_for_user(user, income_categories, expense_categories, months: 3)
    transactions = []

    # Current date for reference
    end_date = Date.today
    start_date = end_date - months.months

    # Monthly income transactions (salary on 1st, freelance on 15th)
    (start_date.to_date..end_date.to_date).select { |d| d.day == 1 }.each do |date|
      salary_category = income_categories.find_by(name: "Salary")
      if salary_category
        transactions << {
          amount: rand(3000..5000),
          description: "Monthly Salary",
          transaction_date: date,
          transaction_type: "income",
          user: user,
          category: salary_category,
          payment_method: "Direct Deposit",
          status: "cleared"
        }
      end
    end

    # Freelance income (more variable)
    (start_date.to_date..end_date.to_date).select { |d| d.day == 15 }.each do |date|
      freelance_category = income_categories.find_by(name: "Freelance")
      if freelance_category && rand < 0.7 # 70% chance of freelance income
        transactions << {
          amount: rand(500..1500),
          description: "Freelance project payment",
          transaction_date: date,
          transaction_type: "income",
          user: user,
          category: freelance_category,
          payment_method: "PayPal",
          status: "cleared"
        }
      end
    end

    # Regular expenses
    # Rent (1st of each month)
    housing_category = expense_categories.find_by(name: "Housing")
    if housing_category
      (start_date.to_date..end_date.to_date).select { |d| d.day == 1 }.each do |date|
        transactions << {
          amount: rand(1000..1500),
          description: "Monthly rent",
          transaction_date: date,
          transaction_type: "expense",
          user: user,
          category: housing_category,
          payment_method: "Bank Transfer",
          status: "cleared"
        }
      end
    end

    # Utilities (around 15th of month)
    utilities_category = expense_categories.find_by(name: "Utilities")
    if utilities_category
      (start_date.to_date..end_date.to_date).select { |d| d.day >= 14 && d.day <= 16 }.each do |date|
        transactions << {
          amount: rand(100..200),
          description: "Utilities payment",
          transaction_date: date,
          transaction_type: "expense",
          user: user,
          category: utilities_category,
          payment_method: "Credit Card",
          status: "cleared"
        }
      end
    end

    # Groceries (weekly)
    groceries_category = expense_categories.find_by(name: "Groceries")
    if groceries_category
      # Weekly grocery trips (assume every Saturday)
      (start_date.to_date..end_date.to_date).select { |d| d.wday == 6 }.each do |date|
        transactions << {
          amount: rand(50..120),
          description: "Weekly groceries",
          transaction_date: date,
          transaction_type: "expense",
          user: user,
          category: groceries_category,
          payment_method: "Credit Card",
          status: "cleared"
        }
      end
    end

    # Dining out (random dates, a few times per month)
    dining_category = expense_categories.find_by(name: "Dining Out")
    if dining_category
      # Random dining out experiences
      8.times do |i|
        random_date = start_date + rand((end_date - start_date)).days
        transactions << {
          amount: rand(25..80),
          description: ["Restaurant dinner", "Lunch with friends", "Coffee shop", "Take-out dinner"].sample,
          transaction_date: random_date,
          transaction_type: "expense",
          user: user,
          category: dining_category,
          payment_method: ["Credit Card", "Debit Card", "Cash"].sample,
          status: "cleared"
        }
      end
    end

    # Transportation (random dates)
    transport_category = expense_categories.find_by(name: "Transportation")
    if transport_category
      12.times do |i|
        random_date = start_date + rand((end_date - start_date)).days
        transactions << {
          amount: rand(15..60),
          description: ["Fuel", "Subway pass", "Taxi ride", "Bus ticket"].sample,
          transaction_date: random_date,
          transaction_type: "expense",
          user: user,
          category: transport_category,
          payment_method: ["Credit Card", "Debit Card", "Cash"].sample,
          status: "cleared"
        }
      end
    end

    # Entertainment (random dates)
    entertainment_category = expense_categories.find_by(name: "Entertainment")
    if entertainment_category
      6.times do |i|
        random_date = start_date + rand((end_date - start_date)).days
        transactions << {
          amount: rand(20..50),
          description: ["Movie tickets", "Streaming subscription", "Concert tickets", "Video game"].sample,
          transaction_date: random_date,
          transaction_type: "expense",
          user: user,
          category: entertainment_category,
          payment_method: ["Credit Card", "Debit Card"].sample,
          status: "cleared"
        }
      end
    end

    # Add some user-specific transactions if they have custom categories
    if user.categories.any?
      user.categories.each do |category|
        3.times do
          random_date = start_date + rand((end_date - start_date)).days
          amount = category.category_type == "income" ? rand(100..500) : rand(20..100)

          transactions << {
            amount: amount,
            description: "#{category.name} - #{["Regular", "One-time", "Special"].sample} #{category.category_type}",
            transaction_date: random_date,
            transaction_type: category.category_type,
            user: user,
            category: category,
            payment_method: ["Credit Card", "Debit Card", "Cash", "Bank Transfer"].sample,
            status: ["pending", "cleared"].sample
          }
        end
      end
    end

    # Actually create all the transactions
    transactions.each do |txn|
      Transaction.create!(**txn)
    end

    puts "Created #{transactions.count} transactions for #{user.first_name}"
  end

  # Create transactions for users
  create_transactions_for_user(john, john_available_income_cats, john_available_expense_cats)
  create_transactions_for_user(jane, jane_available_income_cats, jane_available_expense_cats)

  puts "Creating budgets..."
  # Create budgets for John
  john_budgets = [
    {
      name: "Monthly Groceries",
      amount: 500.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: john,
      category: Category.find_by(name: "Groceries"),
      recurrence: "monthly",
      notification_threshold: 80,
      notes: "Try to keep under budget this month",
      is_active: true
    },
    {
      name: "Dining Budget",
      amount: 300.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: john,
      category: Category.find_by(name: "Dining Out"),
      recurrence: "monthly",
      notification_threshold: 75,
      notes: "Limit to twice per week",
      is_active: true
    },
    {
      name: "Entertainment Spending",
      amount: 150.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: john,
      category: Category.find_by(name: "Entertainment"),
      recurrence: "monthly",
      notification_threshold: 90,
      is_active: true
    },
    {
      name: "Dog Care Expenses",
      amount: 200.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: john,
      category: Category.find_by(name: "Dog Care", user: john),
      recurrence: "monthly",
      notification_threshold: 85,
      notes: "Includes food and regular checkups",
      is_active: true
    }
  ]

  # Create budgets for Jane
  jane_budgets = [
    {
      name: "Monthly Groceries",
      amount: 400.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: jane,
      category: Category.find_by(name: "Groceries"),
      recurrence: "monthly",
      notification_threshold: 80,
      is_active: true
    },
    {
      name: "Art Supplies Budget",
      amount: 250.00,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month,
      user: jane,
      category: Category.find_by(name: "Art Supplies", user: jane),
      recurrence: "monthly",
      notification_threshold: 70,
      notes: "For oil painting project",
      is_active: true
    },
    {
      name: "Quarterly Shopping Budget",
      amount: 600.00,
      start_date: Date.today.beginning_of_quarter,
      end_date: Date.today.end_of_quarter,
      user: jane,
      category: Category.find_by(name: "Shopping"),
      recurrence: "quarterly",
      notification_threshold: 85,
      notes: "Seasonal clothing shopping",
      is_active: true
    }
  ]

  # Create all budgets
  [john_budgets, jane_budgets].each do |budget_group|
    budget_group.each do |budget|
      Budget.create!(**budget)
    end
  end

  puts "Seed data created successfully!"
  puts "Stats:"
  puts "  Users: #{User.count}"
  puts "  Categories: #{Category.count} (#{Category.where(category_type: 'income').count} income, #{Category.where(category_type: 'expense').count} expense)"
  puts "  Transactions: #{Transaction.count} (#{Transaction.where(transaction_type: 'income').count} income, #{Transaction.where(transaction_type: 'expense').count} expense)"
  puts "  Budgets: #{Budget.count}"
