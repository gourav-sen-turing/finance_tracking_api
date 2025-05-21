module Api
  module V1
    class TransactionsController < ApplicationController
      include SecurityHeaders
      before_action :authenticate_user!
      rescue_from API::InsufficientFundsError, with: :handle_insufficient_funds
      rescue_from API::AccountLockedError, with: :handle_account_locked
      rescue_from API::TransactionLimitExceededError, with: :handle_transaction_limit

      # GET /api/v1/transactions
      def index
        # Build and execute the query
        transactions = TransactionQuery.new(current_user.transactions, params).call

        # Apply pagination
        page = (params[:page] || 1).to_i
        per_page = [params[:per_page].to_i, 100].max

        paginated_transactions = transactions.page(page).per(per_page)

        # Calculate summary metrics if requested
        if params[:include_summary] == 'true'
          summary = calculate_summary(transactions)
        end

        # Eager load associations
        paginated_transactions = paginated_transactions.includes(:category, :account)

        # Prepare response
        response = {
          transactions: paginated_transactions,
          meta: {
            total_count: paginated_transactions.total_count,
            total_pages: paginated_transactions.total_pages,
            current_page: page,
            per_page: per_page
          }
        }

        response[:summary] = summary if summary.present?

        render_success(response)
      end

      # GET /api/v1/transactions/:id
      def show
        render_success({ transaction: @transaction })
      end

      # POST /api/v1/transactions
      def create
        @financial_transaction = current_user.financial_transactions.new(financial_transaction_params)

        if @financial_transaction.save
          # Process transaction for goals (this is now handled by the model callback)

          # Apply tags if provided
          if params[:tag_ids].present?
            params[:tag_ids].each do |tag_id|
              if current_user.tags.exists?(id: tag_id)
                @financial_transaction.taggings.create(tag_id: tag_id)
              end
            end
          end

          render json: @financial_transaction, status: :created
        else
          render json: { errors: @financial_transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/transactions/:id
      def update
        # Validate transaction parameters
        validation_errors = TransactionParamValidator.validate(transaction_params)

        if validation_errors.any?
          return render_error("Validation failed", :unprocessable_entity, validation_errors)
        end

        # Update transaction using service
        result = TransactionService.update_transaction(@transaction, transaction_params)

        if result[:success]
          render_success({ transaction: result[:transaction] })
        else
          render_validation_error(result[:transaction])
        end
      end

      # DELETE /api/v1/transactions/:id
      def destroy
        result = TransactionService.delete_transaction(@transaction)

        if result[:success]
          render_success({ message: "Transaction successfully deleted" })
        else
          render_error("Failed to delete transaction", :unprocessable_entity)
        end
      end

      private

      def handle_transaction_limit(exception)
        error_response(
          status: 422,
          code: "TRANSACTION_LIMIT_EXCEEDED",
          message: "The transaction amount exceeds your current limit",
          details: {
            requested_amount: exception.requested_amount,
            current_limit: exception.current_limit
          }
        )
      end

      def handle_account_locked(exception)
        error_response(
          status: 422,
          code: "ACCOUNT_LOCKED",
          message: "The account is currently locked",
          details: {
            account_id: exception.account_id,
            reason: exception.reason
          }
        )
      end

      def transaction_params
        params.require(:transaction).permit(
          :amount,
          :date,
          :description,
          :transaction_type,
          :category_id,
          :account_id,
          :notes,
          :payment_method_id
        )
      end

      def calculate_summary(transactions)
        income_total = transactions.where(transaction_type: 'income').sum(:amount)
        expense_total = transactions.where(transaction_type: 'expense').sum(:amount)

        {
          income_total: income_total,
          expense_total: expense_total,
          net_total: income_total - expense_total
        }
      end
    end
  end
end
