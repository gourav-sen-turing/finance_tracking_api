class UserSerializer < BaseSerializer
  # Attributes to be serialized
  attributes :id, :email, :first_name, :last_name, :created_at, :updated_at

  # Optionally, add a custom attribute for the full name if needed
  attribute :full_name do |user|
    "#{user.first_name} #{user.last_name}"
  end

  # Remove password digest from serialized output
  attribute :password_digest do |user|
    nil
  end

  # Add relationship definitions
  has_many :transactions, if: Proc.new { |record, params| params[:include_transactions] }
  has_many :budgets, if: Proc.new { |record, params| params[:include_budgets] }

  # Custom links
  link :self do |user|
    "/api/v1/users/#{user.id}"
  end
end
