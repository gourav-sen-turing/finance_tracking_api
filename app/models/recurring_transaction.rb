class RecurringTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :category

  has_many :financial_transactions, dependent: :nullify
  has_many :notifications, as: :source, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_type, presence: true, inclusion: { in: ['income', 'expense'] }
  validates :frequency, presence: true, inclusion: { in: ['daily', 'weekly', 'monthly', 'yearly'] }
  validates :interval, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :start_date, presence: true
  validate :end_date_after_start_date, if: -> { end_date.present? }
  validate :validate_frequency_specific_fields

  # Notify when a recurring transaction is generated
  def notify_transaction_generated(transaction)
    Notification.notify(
      user,
      NotificationType::RECURRING_TRANSACTION_PROCESSED,
      "Recurring transaction processed: #{title}",
      "A #{transaction_type} of #{amount} for '#{title}' has been added to your transactions.",
      self,
      {
        recurring_transaction_id: id,
        transaction_id: transaction.id,
        amount: amount,
        transaction_type: transaction_type,
        date: transaction.date.to_s
      }
    )
  end

  # Override generate_transaction to add notification
  def generate_transaction(occurrence_date = nil)
    transaction = super

    # Notify user that transaction was generated
    notify_transaction_generated(transaction) if transaction

    transaction
  end

  # Frequency-specific validations
  def validate_frequency_specific_fields
    case frequency
    when 'monthly'
      if day_of_month.present?
        unless day_of_month.between?(1, 31)
          errors.add(:day_of_month, "must be between 1 and 31")
        end
      end
    when 'weekly'
      if day_of_week.present?
        unless day_of_week.between?(0, 6)
          errors.add(:day_of_week, "must be between 0 (Sunday) and 6 (Saturday)")
        end
      end
    end
  end

  # Validate end_date is after start_date
  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after the start date")
    end
  end

  # Method to determine if transaction should be generated
  def should_generate?(current_date = Date.current)
    return false unless active
    return false if end_date.present? && current_date > end_date

    # If never generated before, check against start date
    last_date = last_generated_date || start_date - interval_period

    # Calculate the next occurrence after the last generated date
    next_date = calculate_next_occurrence(last_date)

    # If next occurrence is on or before the current date, we should generate
    next_date <= current_date
  end

  # Method to calculate the next occurrence date
  def calculate_next_occurrence(from_date)
    case frequency
    when 'daily'
      from_date + interval.days
    when 'weekly'
      next_date = from_date + (interval * 7).days

      # Adjust to specific day of week if specified
      if day_of_week.present?
        # Adjust to the specified day of week
        days_to_add = (day_of_week - next_date.wday) % 7
        next_date = next_date + days_to_add.days
      end

      next_date
    when 'monthly'
      next_date = from_date + interval.months

      # Adjust to specific day of month if specified
      if day_of_month.present?
        # Handle edge cases like 31st of the month
        max_days = Date.new(next_date.year, next_date.month, -1).day
        actual_day = [day_of_month, max_days].min
        next_date = Date.new(next_date.year, next_date.month, actual_day)
      end

      next_date
    when 'yearly'
      from_date + interval.years
    end
  end

  # Method to generate a transaction based on this recurring transaction
  def generate_transaction(occurrence_date = nil)
    # Default to next occurrence date if date not specified
    occurrence_date ||= calculate_next_occurrence(last_generated_date || start_date)

    transaction = user.financial_transactions.new(
      title: title,
      description: "#{description} (Recurring: #{frequency})",
      amount: amount,
      transaction_type: transaction_type,
      category_id: category_id,
      date: occurrence_date,
      recurring_transaction_id: id
    )

    if transaction.save
      update(last_generated_date: occurrence_date)
      transaction
    else
      # Handle error
      Rails.logger.error "Failed to generate recurring transaction ##{id}: #{transaction.errors.full_messages.join(", ")}"
      nil
    end
  end

  # Generate all transactions that should have occurred up to current_date
  def generate_all_pending(current_date = Date.current)
    return [] unless active
    return [] if end_date.present? && current_date > end_date

    generated_transactions = []
    check_date = last_generated_date || (start_date - 1.day)

    while check_date < current_date
      next_date = calculate_next_occurrence(check_date)
      break if next_date > current_date
      break if end_date.present? && next_date > end_date

      transaction = generate_transaction(next_date)
      generated_transactions << transaction if transaction

      check_date = next_date
    end

    generated_transactions
  end

  private

  # Helper to get interval period based on frequency
  def interval_period
    case frequency
    when 'daily'
      interval.days
    when 'weekly'
      (interval * 7).days
    when 'monthly'
      interval.months
    when 'yearly'
      interval.years
    end
  end
end
