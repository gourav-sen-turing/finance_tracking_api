class TransactionSerializer
  include JSONAPI::Serializer

  attributes :description, :amount, :transaction_date, :transaction_type,
             :notes, :recurring, :recurring_interval, :created_at, :updated_at

  attribute :amount do |transaction|
    transaction.amount.to_f
  end

  attribute :transaction_date do |transaction|
    transaction.transaction_date.iso8601 if transaction.transaction_date
  end

  belongs_to :category, serializer: CategorySerializer
end
