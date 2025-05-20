class TransactionQuery
  attr_reader :relation, :params

  def initialize(relation = Transaction.all, params = {})
    @relation = relation
    @params = params
  end

  def call
    query = relation
    query = filter_by_date_range(query)
    query = filter_by_type(query)
    query = filter_by_category(query)
    query = filter_by_amount_range(query)
    query = filter_by_search_term(query)
    query = apply_sorting(query)
    query
  end

  private

  def filter_by_date_range(query)
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        query = query.where(date: start_date..end_date)
      rescue ArgumentError
        # Invalid date format, return original query
      end
    elsif params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        query = query.where("date >= ?", start_date)
      rescue ArgumentError
        # Invalid date format, return original query
      end
    elsif params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        query = query.where("date <= ?", end_date)
      rescue ArgumentError
        # Invalid date format, return original query
      end
    end
    query
  end

  def filter_by_type(query)
    if params[:type].present?
      query = query.where(transaction_type: params[:type])
    end
    query
  end

  def filter_by_category(query)
    if params[:category_id].present?
      query = query.where(category_id: params[:category_id])
    end
    query
  end

  def filter_by_amount_range(query)
    if params[:min_amount].present?
      query = query.where("amount >= ?", params[:min_amount])
    end
    if params[:max_amount].present?
      query = query.where("amount <= ?", params[:max_amount])
    end
    query
  end

  def filter_by_search_term(query)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      query = query.where("description ILIKE ?", search_term)
    end
    query
  end

  def apply_sorting(query)
    sort_column = params[:sort] || 'date'
    sort_direction = %w[asc desc].include?(params[:direction]&.downcase) ? params[:direction] : 'desc'

    valid_sort_columns = %w[date amount description transaction_type category_id]

    if valid_sort_columns.include?(sort_column)
      query.order("#{sort_column} #{sort_direction}")
    else
      query.order(date: :desc)
    end
  end
end
