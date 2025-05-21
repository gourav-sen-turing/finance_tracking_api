module Api
  module V1
    class TagsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_tag, only: [:show, :update, :destroy]

      # GET /api/v1/tags
      def index
        @tags = current_user.tags.order(:name)
        render json: { tags: @tags }
      end

      # GET /api/v1/tags/1
      def show
        render json: { tag: @tag }
      end

      # POST /api/v1/tags
      def create
        @tag = current_user.tags.new(tag_params)

        if @tag.save
          render json: { tag: @tag }, status: :created
        else
          render json: { errors: @tag.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/tags/1
      def update
        if @tag.update(tag_params)
          render json: { tag: @tag }
        else
          render json: { errors: @tag.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tags/1
      def destroy
        @tag.destroy
        head :no_content
      end

      # POST /api/v1/financial_transactions/1/tags
      def tag_transaction
        transaction = current_user.financial_transactions.find(params[:transaction_id])
        tag_ids = params[:tag_ids] || []

        # Clear existing tags if replace flag is true
        if params[:replace] == 'true'
          transaction.taggings.destroy_all
        end

        # Add new tags
        tag_ids.each do |tag_id|
          if current_user.tags.exists?(id: tag_id) && !transaction.taggings.exists?(tag_id: tag_id)
            transaction.taggings.create!(tag_id: tag_id)
          end
        end

        # Process goals after tagging
        current_user.financial_goals.active.where(tracking_method: 'tag').each do |goal|
          goal.process_transaction(transaction)
        end

        render json: {
          transaction_id: transaction.id,
          tags: transaction.tags
        }
      end

      private

      def set_tag
        @tag = current_user.tags.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Tag not found' }, status: :not_found
      end

      def tag_params
        params.require(:tag).permit(:name)
      end
    end
  end
end
