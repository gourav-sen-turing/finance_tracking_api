class User < ApplicationRecord
  # Encrypt password
  has_secure_password

  # Associations
  has_many :transactions, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :financial_goals, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy
  has_many :notifications, dependent: :destroy

  after_create :setup_notification_preferences

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password_digest, presence: true

  # Email format validation
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  def name
    "#{first_name} #{last_name}".strip
  end

  def generate_password_reset_token!
    # Generate a secure random token
    loop do
      self.reset_password_token = SecureRandom.urlsafe_base64(32)
      break unless User.exists?(reset_password_token: reset_password_token)
    end

    # Set the timestamp
    self.reset_password_sent_at = Time.current
    save!

    # Return the token for use in the response
    reset_password_token
  end

  def clear_password_reset_token!
    self.reset_password_token = nil
    self.reset_password_sent_at = nil
    save!
  end

  def password_reset_token_valid?
    # Token is present and was sent less than 24 hours ago
    reset_password_token.present? &&
    reset_password_sent_at.present? &&
    reset_password_sent_at > 24.hours.ago
  end

  def unread_notification_count
    notifications.unread.count
  end

  private

  def setup_notification_preferences
    NotificationPreference.create_defaults_for(self)
  end
end
