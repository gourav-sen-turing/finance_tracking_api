class TransactionSerializer < ActiveModel::Serializer
  attributes :id, :amount, :date, :description, :transaction_type,
             :created_at, :updated_at, :notes

  belongs_to :category
  belongs_to :account, if: -> { object.account_id.present? }
  belongs_to :payment_method, if: -> { object.payment_method_id.present? }

  # Add custom methods as needed
  def date
    object.date.iso8601 if object.date
  end
end
