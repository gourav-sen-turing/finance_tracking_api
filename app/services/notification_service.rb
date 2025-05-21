class NotificationService
  # Budget alerts
  def self.check_budget_alerts
    # Find budgets that are approaching/exceeding their limits
    Budget.active.find_each do |budget|
      user = budget.user

      # Skip if user has disabled this notification
      next unless Notification.should_notify?(user, NotificationType::BUDGET_ALERT)

      preference = user.notification_preferences.joins(:notification_type)
                     .find_by(notification_types: { code: NotificationType::BUDGET_ALERT })

      threshold = preference&.threshold_value || 80 # Default 80%

      # Calculate current spending percentage
      spent_percentage = budget.calculate_spent_percentage

      if spent_percentage >= threshold && spent_percentage < 100
        # Approaching budget limit
        Notification.notify(
          user,
          NotificationType::BUDGET_ALERT,
          "Approaching budget limit for #{budget.category.name}",
          "You've used #{spent_percentage.round}% of your #{budget.category.name} budget for this period.",
          budget,
          {
            budget_id: budget.id,
            percentage: spent_percentage.round,
            amount_spent: budget.amount_spent,
            budget_limit: budget.amount
          }
        )
      elsif spent_percentage >= 100
        # Exceeded budget limit
        Notification.notify(
          user,
          NotificationType::BUDGET_ALERT,
          "Budget exceeded for #{budget.category.name}",
          "You've exceeded your #{budget.category.name} budget for this period by #{(budget.amount_spent - budget.amount).round(2)}.",
          budget,
          {
            budget_id: budget.id,
            percentage: spent_percentage.round,
            amount_spent: budget.amount_spent,
            budget_limit: budget.amount,
            amount_exceeded: (budget.amount_spent - budget.amount).round(2)
          }
        )
      end
    end
  end

  # Goal milestone notifications
  def self.check_goal_milestones
    FinancialGoal.active.find_each do |goal|
      user = goal.user

      # Skip if user has disabled this notification
      next unless Notification.should_notify?(user, NotificationType::GOAL_MILESTONE)

      preference = user.notification_preferences.joins(:notification_type)
                     .find_by(notification_types: { code: NotificationType::GOAL_MILESTONE })

      milestone_step = preference&.threshold_value || 25 # Default 25% increments

      # Calculate current percentage and the last milestone we would have notified for
      current_percentage = goal.progress_percentage
      last_milestone = (current_percentage / milestone_step).floor * milestone_step

      # Skip if no milestone reached or already notified
      next if last_milestone <= 0 ||
              goal.notifications.exists?(notification_type: NotificationType.find_by(code: NotificationType::GOAL_MILESTONE),
                                         metadata: { milestone_percentage: last_milestone })

      # Create milestone notification
      Notification.notify(
        user,
        NotificationType::GOAL_MILESTONE,
        "#{last_milestone}% milestone reached for #{goal.title}",
        "You're making great progress! You've reached #{last_milestone}% of your goal to #{goal.title}.",
        goal,
        {
          goal_id: goal.id,
          milestone_percentage: last_milestone,
          current_percentage: current_percentage.round(1),
          current_amount: goal.current_amount,
          target_amount: goal.target_amount
        }
      )
    end
  end

  # Recurring transaction reminders
  def self.check_upcoming_recurring_transactions
    # Find recurring transactions that are coming up soon
    RecurringTransaction.where(active: true).find_each do |recurring|
      user = recurring.user

      # Skip if user has disabled this notification
      next unless Notification.should_notify?(user, NotificationType::RECURRING_TRANSACTION_UPCOMING)

      preference = user.notification_preferences.joins(:notification_type)
                     .find_by(notification_types: { code: NotificationType::RECURRING_TRANSACTION_UPCOMING })

      days_before = preference&.threshold_value || 3 # Default 3 days notice

      # Calculate next occurrence
      next_date = recurring.calculate_next_occurrence(recurring.last_generated_date || recurring.start_date)

      # Check if it's within our notification window
      days_until = (next_date - Date.current).to_i

      # Only notify if it's exactly the preferred number of days before
      # (to avoid duplicate notifications)
      if days_until == days_before
        Notification.notify(
          user,
          NotificationType::RECURRING_TRANSACTION_UPCOMING,
          "Upcoming: #{recurring.title}",
          "You have a recurring #{recurring.transaction_type} of #{recurring.amount} scheduled for #{next_date.strftime('%A, %B %d')}.",
          recurring,
          {
            recurring_transaction_id: recurring.id,
            amount: recurring.amount,
            transaction_type: recurring.transaction_type,
            due_date: next_date.to_s,
            days_until: days_until
          }
        )
      end
    end
  end

  # Additional notification triggers...

  # Monthly summary notifications
  def self.generate_monthly_summaries
    # Beginning of previous month
    previous_month_start = Date.current.beginning_of_month - 1.month
    previous_month_end = previous_month_start.end_of_month
    month_name = previous_month_start.strftime('%B %Y')

    User.find_each do |user|
      # Skip if user has disabled monthly summaries
      next unless Notification.should_notify?(user, NotificationType::MONTHLY_SUMMARY)

      # Get transaction data for the month
      transactions = user.financial_transactions.where(date: previous_month_start..previous_month_end)

      # Skip if no activity
      next if transactions.empty?

      # Calculate key metrics
      income = transactions.income.sum(:amount)
      expenses = transactions.expense.sum(:amount)
      savings = income - expenses
      savings_rate = income > 0 ? (savings / income * 100).round(1) : 0

      # Top expense categories
      top_categories = transactions.expense
                         .joins(:category)
                         .group('categories.name')
                         .sum(:amount)
                         .sort_by { |_, amount| -amount }
                         .take(3)
                         .map { |name, amount| { name: name, amount: amount } }

      Notification.notify(
        user,
        NotificationType::MONTHLY_SUMMARY,
        "Your #{month_name} Financial Summary",
        generate_monthly_summary_text(income, expenses, savings_rate, top_categories, month_name),
        nil, # No specific source
        {
          month: previous_month_start.strftime('%Y-%m'),
          income: income,
          expenses: expenses,
          savings: savings,
          savings_rate: savings_rate,
          transaction_count: transactions.count,
          top_categories: top_categories
        }
      )
    end
  end

  def self.generate_monthly_summary_text(income, expenses, savings_rate, top_categories, month_name)
    summary = "Here's your financial summary for #{month_name}:\n\n"
    summary += "• Total Income: #{income}\n"
    summary += "• Total Expenses: #{expenses}\n"
    summary += "• Savings Rate: #{savings_rate}%\n\n"

    if top_categories.any?
      summary += "Top spending categories:\n"
      top_categories.each_with_index do |category, index|
        summary += "#{index + 1}. #{category[:name]}: #{category[:amount]}\n"
      end
    end

    summary
  end
end
