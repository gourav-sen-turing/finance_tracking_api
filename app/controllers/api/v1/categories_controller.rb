module Api
  module V1
    class CategoriesController < ApplicationController
      before_action :authenticate_user
      before_action :set_category, only: [:show, :update, :destroy]

      # GET /api/v1/categories
      def index
        @categories = current_user.categories.order(:name)

        render json: CategorySerializer.new(@categories).serializable_hash.to_json
      end

      # GET /api/v1/categories/:id
      def show
        render json: CategorySerializer.new(@category).serializable_hash.to_json
      end

      # POST /api/v1/categories
      def create
        @category = current_user.categories.build(category_params)

        if @category.save
          render json: CategorySerializer.new(@category).serializable_hash.to_json,
                 status: :created,
                 location: api_v1_category_path(@category)
        else
          render json: {
            errors: @category.errors.messages.map { |field, msgs|
              msgs.map { |msg| { source: { pointer: "/data/attributes/#{field}" }, detail: msg } }
            }.flatten
          }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/categories/:id
      def update
        if @category.update(category_params)
          render json: CategorySerializer.new(@category).serializable_hash.to_json
        else
          render json: {
            errors: @category.errors.messages.map { |field, msgs|
              msgs.map { |msg| { source: { pointer: "/data/attributes/#{field}" }, detail: msg } }
            }.flatten
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/categories/:id
      def destroy
        # Check if the category has associated transactions
        if @category.financial_transactions.exists?
          render json: {
            errors: [{
              title: "Cannot delete category with transactions",
              detail: "This category has associated transactions and cannot be deleted. You may reassign the transactions to another category first."
            }]
          }, status: :unprocessable_entity
          return
        end

        @category.destroy
        head :no_content
      end

      def financial_transactions
        @transactions = @category.financial_transactions.order(date: :desc).page(params[:page]).per(params[:per_page] || 10)

        render json: {
          category: CategorySerializer.new(@category).serializable_hash,
          financial_transactions: FinancialTransactionSerializer.new(@transactions).serializable_hash,
          pagination: {
            total_pages: @transactions.total_pages,
            current_page: @transactions.current_page,
            total_count: @transactions.total_count
          }
        }
      end

      private

      def set_category
        @category = current_user.categories.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          errors: [{ title: "Record not found", detail: "Category not found or does not belong to you" }]
        }, status: :not_found
      end

      def category_params
        params.require(:category).permit(:name, :description, :color)
      end
    end
  end
end
