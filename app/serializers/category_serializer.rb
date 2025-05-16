class CategorySerializer
  include JSONAPI::Serializer

  attributes :name, :description, :color, :created_at, :updated_at

  # Include transaction counts as a computed attribute
  attribute :transaction_count do |category|
    category.financial_transactions.count
  end

  # Include total amount spent in this category
  attribute :total_spent do |category|
    category.total_spent.to_f
  end
end
