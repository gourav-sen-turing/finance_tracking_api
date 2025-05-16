class Category < ApplicationRecord
  belongs_to :user, optional: true  # Optional for system default categories
  belongs_to :parent_category, class_name: 'Category', optional: true
  has_many :sub_categories, class_name: 'Category', foreign_key: 'parent_category_id', dependent: :nullify

  # Transactions relationship with type filtering
  has_many :transactions, dependent: :nullify
  has_many :income_transactions, -> { where(transaction_type: 'income') },
           class_name: 'Transaction', dependent: :nullify
  has_many :expense_transactions, -> { where(transaction_type: 'expense') },
           class_name: 'Transaction', dependent: :nullify

  has_many :budgets, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :category_type, presence: true, inclusion: { in: ['income', 'expense'] }
  validate :parent_category_type_matches

  # Scopes
  scope :income, -> { where(category_type: 'income') }
  scope :expense, -> { where(category_type: 'expense') }
  scope :top_level, -> { where(parent_category_id: nil) }

  private

  # Ensure parent category type matches
  def parent_category_type_matches
    if parent_category_id.present? &&
       parent_category.present? &&
       parent_category.category_type != category_type
      errors.add(:parent_category, "type must match this category's type")
    end
>>>>>>> origin/main
  end
end
