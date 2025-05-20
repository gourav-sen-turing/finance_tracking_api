class TransactionParamValidator
  def self.validate(params)
    errors = []

    # Validate amount
    if params[:amount].blank?
      errors << { field: "amount", message: "Amount is required" }
    elsif !numeric?(params[:amount]) || params[:amount].to_f <= 0
      errors << { field: "amount", message: "Amount must be a positive number" }
    end

    # Validate transaction type
    if params[:transaction_type].blank?
      errors << { field: "transaction_type", message: "Transaction type is required" }
    elsif !%w[income expense transfer].include?(params[:transaction_type].to_s)
      errors << { field: "transaction_type", message: "Transaction type must be income, expense, or transfer" }
    end

    # Validate date
    if params[:date].blank?
      errors << { field: "date", message: "Date is required" }
    else
      begin
        Date.parse(params[:date].to_s)
      rescue ArgumentError
        errors << { field: "date", message: "Date must be in a valid format" }
      end
    end

    # Validate category
    if params[:category_id].blank?
      errors << { field: "category_id", message: "Category is required" }
    end

    errors
  end

  private

  def self.numeric?(value)
    begin
      Float(value)
      true
    rescue
      false
    end
  end
end
