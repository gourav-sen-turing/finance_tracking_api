module Api
  module V1
    class TransactionsController < ApplicationController
      before_action :authenticate_user
      before_action :set_transaction, only: [:show, :update, :destroy]

      # GET /api/v1/transactions
      def index
        byebug
        unless current_user
          Rails.logger.error "Current user is nil in index action"
          return render json: { error: 'Authentication required' }, status: :unauthorized
        end

        @transactions = current_user.transactions.order(transaction_date: :desc)

        # Apply optional filters
        @transactions = apply_filters(@transactions)

        # Implement pagination
        paginated_transactions = @transactions.page(params[:page] || 1).per(params[:per_page] || 25)

        render json: TransactionSerializer.new(paginated_transactions,
          meta: {
            total_count: paginated_transactions.total_count,
            total_pages: paginated_transactions.total_pages,
            current_page: paginated_transactions.current_page,
            income: current_user.transactions.incomes.sum(:amount),
            expenses: current_user.transactions.expenses.sum(:amount)
          }
        )
      end

      # GET /api/v1/transactions/:id
      def show
        render json: TransactionSerializer.new(@transaction)
      end

      # POST /api/v1/transactions
      def create
        @transaction = current_user.transactions.new(transaction_params)

        if @transaction.save
          render json: TransactionSerializer.new(@transaction), status: :created
        else
          render json: { errors: format_errors(@transaction.errors) }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/transactions/:id
      def update
        if @transaction.update(transaction_params)
          render json: TransactionSerializer.new(@transaction)
        else
          render json: { errors: format_errors(@transaction.errors) }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/transactions/:id
      def destroy
        @transaction.destroy
        head :no_content
      end

      private

      def set_transaction
        @transaction = current_user.transactions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Transaction not found' }, status: :not_found
      end

      def transaction_params
        params.require(:transaction).permit(
          :description,
          :amount,
          :transaction_date,
          :transaction_type,
          :category_id,
          :notes,
          :recurring,
          :recurring_interval
        )
      end

      def apply_filters(transactions)
        # Filter by category
        transactions = transactions.where(category_id: params[:category_id]) if params[:category_id].present?

        # Filter by transaction type (income/expense)
        transactions = transactions.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?

        # Filter by date range
        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date]) rescue nil
          end_date = Date.parse(params[:end_date]) rescue nil

          if start_date && end_date
            transactions = transactions.where('transaction_date BETWEEN ? AND ?', start_date, end_date)
          end
        end

        # Search by description
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          transactions = transactions.where('description ILIKE ?', search_term)
        end

        transactions
      end

      def format_errors(errors)
        errors.map do |attribute, message|
          {
            source: { pointer: "/data/attributes/#{attribute}" },
            detail: message
          }
        end
      end
    end
  end
end
