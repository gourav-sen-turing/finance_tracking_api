class TransactionService
  def self.create_transaction(user, params)
    transaction = user.transactions.new(params)

    if transaction.save
      # Update account balance if needed
      if transaction.account.present?
        update_account_balance(transaction)
      end

      { success: true, transaction: transaction }
    else
      { success: false, errors: transaction.errors }
    end
  end

  def self.update_transaction(transaction, params)
    # Store original values for balance adjustment
    original_amount = transaction.amount
    original_type = transaction.transaction_type
    original_account_id = transaction.account_id

    if transaction.update(params)
      # Handle account balance updates if amount, type or account changed
      if transaction.amount != original_amount ||
         transaction.transaction_type != original_type ||
         transaction.account_id != original_account_id

        # Revert original account balance change if account hasn't changed
        if original_account_id == transaction.account_id
          reverse_account_balance_change(transaction.account, original_amount, original_type)
        else
          # Handle account change
          if original_account_id.present?
            original_account = Account.find_by(id: original_account_id)
            reverse_account_balance_change(original_account, original_amount, original_type) if original_account
          end
        end

        # Apply new change
        update_account_balance(transaction)
      end

      { success: true, transaction: transaction }
    else
      { success: false, errors: transaction.errors }
    end
  end

  def self.delete_transaction(transaction)
    # Revert account balance change before destroying
    if transaction.account.present?
      reverse_account_balance_change(transaction.account, transaction.amount, transaction.transaction_type)
    end

    transaction.destroy

    { success: true }
  end

  private

  def self.update_account_balance(transaction)
    return unless transaction.account.present?

    if transaction.transaction_type == 'expense'
      transaction.account.update(balance: transaction.account.balance - transaction.amount)
    elsif transaction.transaction_type == 'income'
      transaction.account.update(balance: transaction.account.balance + transaction.amount)
    end
  end

  def self.reverse_account_balance_change(account, amount, transaction_type)
    return unless account.present?

    if transaction_type == 'expense'
      account.update(balance: account.balance + amount)
    elsif transaction_type == 'income'
      account.update(balance: account.balance - amount)
    end
  end
end
