class FinancialGoal < ApplicationRecord
  belongs_to :user
  has_many :goal_contributions, dependent: :destroy
  has_many :goal_categories, dependent: :destroy
  has_many :categories, through: :goal_categories
  has_many :goal_tags, dependent: :destroy
  has_many :tags, through: :goal_tags
  has_many :notifications, as: :source, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :starting_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :current_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :goal_type, presence: true, inclusion: {
    in: %w[savings debt_reduction emergency_fund investment custom]
  }
  validates :status, inclusion: {
    in: %w[active complete abandoned]
  }
  validates :tracking_method, inclusion: {
    in: %w[category tag account manual]
  }
  validate :target_date_in_future, if: -> { target_date.present? }

  # Status-based scopes
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'complete') }
  scope :abandoned, -> { where(status: 'abandoned') }

  # Type-based scopes
  scope :savings, -> { where(goal_type: 'savings') }
  scope :debt_reduction, -> { where(goal_type: 'debt_reduction') }
  scope :emergency_fund, -> { where(goal_type: 'emergency_fund') }

  # Notify when goal completed
  def mark_as_complete!
    return false if status == 'complete'

    update(status: 'complete', completion_date: Time.current)

    # Send completion notification
    Notification.notify(
      user,
      NotificationType::GOAL_COMPLETED,
      "Congratulations! Goal completed: #{title}",
      "You've successfully reached your goal of #{target_amount} for '#{title}'!",
      self,
      {
        goal_id: id,
        target_amount: target_amount,
        days_to_completion: (completion_date - created_at.to_date).to_i
      }
    )

    true
  end

  # Validate target date is in the future
  def target_date_in_future
    if target_date.present? && target_date < Date.current
      errors.add(:target_date, "must be in the future")
    end
  end

  # Calculate completion percentage
  def progress_percentage
    return 0 if target_amount.zero?
    progress = (current_amount / target_amount * 100).round(2)
    [progress, 100].min # Cap at 100%
  end

  # Calculate amount remaining
  def amount_remaining
    remaining = target_amount - current_amount
    [remaining, 0].max # Ensure never negative
  end

  # Check if goal is complete
  def complete?
    status == 'complete' || current_amount >= target_amount
  end

  # Calculate monthly contribution needed
  def required_monthly_contribution
    return 0 if complete? || target_date.nil?

    months_remaining = ((target_date.year * 12 + target_date.month) -
                       (Date.current.year * 12 + Date.current.month)).to_f

    return 0 if months_remaining <= 0

    (amount_remaining / months_remaining).round(2)
  end

  # Add a contribution
  def add_contribution(amount, transaction = nil, notes = nil)
    contribution = goal_contributions.create!(
      amount: amount,
      financial_transaction_id: transaction&.id,
      contribution_type: transaction ? 'transaction' : 'manual',
      notes: notes
    )

    self.update(current_amount: current_amount + amount)

    # Check if goal is now complete
    if current_amount >= target_amount && status == 'active'
      self.update(status: 'complete', completion_date: Date.current)
    end

    contribution
  end

  # Process a transaction to check if it contributes to this goal
  def process_transaction(transaction)
    # Don't process if not auto-tracking or if goal is complete
    return false unless auto_track && status == 'active'

    case tracking_method
    when 'category'
      return false unless goal_categories.exists?(category_id: transaction.category_id)
    when 'tag'
      return false unless transaction.taggings.joins(:tag).exists?(tags: { id: tag_ids })
    when 'account'
      # If tracking specific accounts
      if tracking_criteria.present?
        return false unless tracking_criteria.include?(transaction.account_id.to_s)
      end
    else
      return false  # Manual tracking
    end

    # Determine contribution amount based on transaction type
    if goal_type == 'debt_reduction'
      # For debt reduction, expenses that match criteria reduce debt (negative contribution)
      return false unless transaction.transaction_type == 'expense'
      amount = transaction.amount
    else
      # For savings goals, income that match criteria add to savings
      return false unless transaction.transaction_type == 'income'
      amount = transaction.amount
    end

    # Add the contribution
    add_contribution(amount, transaction)
    true
  end

  # Recalculate current amount based on all contributions
  def recalculate_progress!
    total = starting_amount + goal_contributions.sum(:amount)
    update(current_amount: total)

    # Update status if needed
    if current_amount >= target_amount && status == 'active'
      update(status: 'complete', completion_date: Date.current)
    elsif current_amount < target_amount && status == 'complete'
      update(status: 'active', completion_date: nil)
    end
  end

  # Get projection data - how goal will progress over time
  def get_projection(months = 12)
    return [] if months <= 0

    # Calculate monthly contribution (actual or required)
    monthly_amount = if contribution_amount.present? && contribution_frequency == 'monthly'
      contribution_amount
    else
      # Analyze past 3 months of contributions to estimate monthly rate
      three_months_ago = 3.months.ago.beginning_of_day
      recent_contributions = goal_contributions.where('created_at > ?', three_months_ago)

      if recent_contributions.any?
        (recent_contributions.sum(:amount) / 3.0).round(2)
      else
        required_monthly_contribution
      end
    end

    projection = []
    projected_amount = current_amount

    months.times do |i|
      month_date = Date.current >> (i + 1) # Advance i+1 months
      projected_amount += monthly_amount

      projection << {
        date: month_date.strftime("%Y-%m"),
        amount: projected_amount.round(2),
        percentage: [(projected_amount / target_amount * 100).round(2), 100].min
      }

      # Stop if we reach the target amount
      break if projected_amount >= target_amount
    end

    projection
  end

  # Check if on track to meet goal by target date
  def on_track?
    return true if complete?
    return false if target_date.nil?

    months_remaining = ((target_date.year * 12 + target_date.month) -
                      (Date.current.year * 12 + Date.current.month)).to_f

    return false if months_remaining <= 0

    # Calculate required amount per month
    required_per_month = amount_remaining / months_remaining

    # Calculate actual monthly progress over last 3 months
    three_months_ago = 3.months.ago.beginning_of_day
    recent_contributions = goal_contributions.where('created_at > ?', three_months_ago)

    if recent_contributions.any?
      actual_monthly_rate = recent_contributions.sum(:amount) / 3.0
      actual_monthly_rate >= required_per_month
    else
      false # No recent activity
    end
  end
end
