module Api
  module V1
    class FinancialGoalsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_financial_goal, only: [:show, :update, :destroy, :contributions, :add_contribution, :add_category, :remove_category]

      # GET /api/v1/financial_goals
      def index
        @goals = current_user.financial_goals

        # Apply filters
        @goals = @goals.where(status: params[:status]) if params[:status].present?
        @goals = @goals.where(goal_type: params[:goal_type]) if params[:goal_type].present?

        # Apply sorting
        sort_column = params[:sort] || 'created_at'
        sort_direction = params[:direction] || 'desc'
        @goals = @goals.order("#{sort_column} #{sort_direction}")

        # Pagination
        @goals = @goals.page(params[:page] || 1).per(params[:per_page] || 10)

        render json: {
          financial_goals: @goals.as_json(include: [:categories], methods: [:progress_percentage, :amount_remaining, :on_track?]),
          pagination: {
            total_pages: @goals.total_pages,
            current_page: @goals.current_page,
            total_count: @goals.total_count
          }
        }
      end

      # GET /api/v1/financial_goals/1
      def show
        render json: {
          financial_goal: @financial_goal.as_json(
            include: [:categories, :tags],
            methods: [:progress_percentage, :amount_remaining, :required_monthly_contribution, :on_track?]
          )
        }
      end

      # POST /api/v1/financial_goals
      def create
        @financial_goal = current_user.financial_goals.new(financial_goal_params)

        # Set current amount as starting amount initially
        @financial_goal.current_amount = @financial_goal.starting_amount if @financial_goal.starting_amount.present?

        if @financial_goal.save
          # Handle category associations
          if params[:category_ids].present?
            params[:category_ids].each do |category_id|
              if current_user.categories.exists?(id: category_id)
                @financial_goal.goal_categories.create(category_id: category_id)
              end
            end
          end

          # Handle tag associations if using tags
          if params[:tag_ids].present?
            params[:tag_ids].each do |tag_id|
              if current_user.tags.exists?(id: tag_id)
                @financial_goal.goal_tags.create(tag_id: tag_id)
              end
            end
          end

          render json: {
            financial_goal: @financial_goal.as_json(
              include: [:categories, :tags],
              methods: [:progress_percentage, :amount_remaining]
            )
          }, status: :created
        else
          render json: { errors: @financial_goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/financial_goals/1
      def update
        if @financial_goal.update(financial_goal_params)
          # If status changed to complete, set completion date
          if @financial_goal.status_changed? && @financial_goal.status == 'complete' && @financial_goal.completion_date.nil?
            @financial_goal.update(completion_date: Date.current)
          end

          render json: {
            financial_goal: @financial_goal.as_json(
              include: [:categories, :tags],
              methods: [:progress_percentage, :amount_remaining]
            )
          }
        else
          render json: { errors: @financial_goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/financial_goals/1
      def destroy
        @financial_goal.destroy
        head :no_content
      end

      # GET /api/v1/financial_goals/1/contributions
      def contributions
        @contributions = @financial_goal.goal_contributions
                        .includes(:financial_transaction)
                        .order(created_at: :desc)
                        .page(params[:page] || 1)
                        .per(params[:per_page] || 20)

        render json: {
          contributions: @contributions.as_json(include: { financial_transaction: { only: [:id, :title, :date, :amount] } }),
          pagination: {
            total_pages: @contributions.total_pages,
            current_page: @contributions.current_page,
            total_count: @contributions.total_count
          }
        }
      end

      # POST /api/v1/financial_goals/1/contributions
      def add_contribution
        amount = params[:amount].to_f
        notes = params[:notes]

        if amount <= 0
          render json: { error: "Contribution amount must be greater than zero" }, status: :unprocessable_entity
          return
        end

        contribution = @financial_goal.add_contribution(amount, nil, notes)

        render json: {
          contribution: contribution,
          goal_progress: {
            current_amount: @financial_goal.current_amount,
            progress_percentage: @financial_goal.progress_percentage,
            status: @financial_goal.status
          }
        }, status: :created
      end

      # POST /api/v1/financial_goals/1/categories
      def add_category
        category_id = params[:category_id]
        category = current_user.categories.find_by(id: category_id)

        if !category
          render json: { error: "Category not found" }, status: :not_found
          return
        end

        if @financial_goal.categories.include?(category)
          render json: { error: "Category already associated with this goal" }, status: :unprocessable_entity
          return
        end

        @financial_goal.goal_categories.create!(category_id: category_id)

        render json: {
          category: category,
          message: "Category successfully added to goal"
        }
      end

      # DELETE /api/v1/financial_goals/1/categories/:category_id
      def remove_category
        category_id = params[:category_id]
        goal_category = @financial_goal.goal_categories.find_by(category_id: category_id)

        if !goal_category
          render json: { error: "Category not associated with this goal" }, status: :not_found
          return
        end

        goal_category.destroy

        render json: { message: "Category successfully removed from goal" }
      end

      # GET /api/v1/financial_goals/1/projection
      def projection
        months = (params[:months] || 12).to_i.clamp(1, 60) # Limit to reasonable range

        projection_data = @financial_goal.get_projection(months)

        render json: {
          projection: projection_data,
          on_track: @financial_goal.on_track?,
          target_date: @financial_goal.target_date,
          required_monthly_contribution: @financial_goal.required_monthly_contribution
        }
      end

      # GET /api/v1/financial_goals/dashboard
      def dashboard
        # Get summary of all goals
        @active_goals = current_user.financial_goals.active
        @completed_goals = current_user.financial_goals.completed.order(completion_date: :desc).limit(5)

        # Calculate overall progress
        total_target = @active_goals.sum(:target_amount)
        total_current = @active_goals.sum(:current_amount)
        overall_percentage = total_target > 0 ? ((total_current / total_target) * 100).round(2) : 0

        # Get closest goals to completion
        closest_to_completion = @active_goals
          .order(Arel.sql('current_amount / target_amount DESC'))
          .limit(3)

        # Get goals requiring attention (least progress or past target date)
        goals_needing_attention = @active_goals
          .where('target_date < ? OR (current_amount / target_amount) < 0.25', Date.current)
          .order(target_date: :asc)
          .limit(3)

        # Recent contributions
        recent_contributions = GoalContribution
          .joins(:financial_goal)
          .where(financial_goals: { user_id: current_user.id })
          .order(created_at: :desc)
          .limit(5)

        render json: {
          summary: {
            active_goals_count: @active_goals.count,
            completed_goals_count: current_user.financial_goals.completed.count,
            total_target_amount: total_target,
            total_current_amount: total_current,
            overall_percentage: overall_percentage
          },
          active_goals: @active_goals.as_json(
            only: [:id, :title, :target_amount, :current_amount, :target_date, :goal_type],
            methods: [:progress_percentage, :on_track?]
          ),
          completed_goals: @completed_goals.as_json(
            only: [:id, :title, :target_amount, :completion_date, :goal_type]
          ),
          closest_to_completion: closest_to_completion.as_json(
            only: [:id, :title, :target_amount, :current_amount],
            methods: [:progress_percentage]
          ),
          goals_needing_attention: goals_needing_attention.as_json(
            only: [:id, :title, :target_amount, :current_amount, :target_date],
            methods: [:progress_percentage, :amount_remaining]
          ),
          recent_contributions: recent_contributions.as_json(
            include: {
              financial_goal: { only: [:id, :title] },
              financial_transaction: { only: [:id, :title] }
            }
          )
        }
      end

      # GET /api/v1/financial_goals/stats
      def stats
        # Monthly contributions for the past year
        start_date = 1.year.ago.beginning_of_month

        # Group by month and sum contributions
        monthly_data = GoalContribution
          .joins(:financial_goal)
          .where(financial_goals: { user_id: current_user.id })
          .where('goal_contributions.created_at >= ?', start_date)
          .group("DATE_TRUNC('month', goal_contributions.created_at)")
          .order("DATE_TRUNC('month', goal_contributions.created_at)")
          .sum(:amount)

        # Format the data for the API response
        monthly_contributions = monthly_data.map do |date, amount|
          {
            month: date.strftime('%Y-%m'),
            amount: amount.round(2)
          }
        end

        # Goal type distribution
        goal_type_data = current_user.financial_goals
          .group(:goal_type)
          .count

        # Completion rate
        total_goals = current_user.financial_goals.count
        completed_goals = current_user.financial_goals.completed.count
        completion_rate = total_goals > 0 ? (completed_goals.to_f / total_goals * 100).round(2) : 0

        # Average time to completion for completed goals
        avg_completion_time = nil
        completed_with_dates = current_user.financial_goals
          .where.not(completion_date: nil)
          .where.not(created_at: nil)

        if completed_with_dates.any?
          total_days = completed_with_dates.sum do |goal|
            (goal.completion_date - goal.created_at.to_date).to_i
          end
          avg_completion_time = (total_days.to_f / completed_with_dates.count).round
        end

        render json: {
          monthly_contributions: monthly_contributions,
          goal_type_distribution: goal_type_data,
          completion_stats: {
            total_goals: total_goals,
            completed_goals: completed_goals,
            completion_rate: completion_rate,
            avg_days_to_completion: avg_completion_time
          }
        }
      end

      private

      def set_financial_goal
        @financial_goal = current_user.financial_goals.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Financial goal not found' }, status: :not_found
      end

      def financial_goal_params
        params.require(:financial_goal).permit(
          :title, :description, :target_amount, :starting_amount,
          :target_date, :goal_type, :status, :contribution_amount,
          :contribution_frequency, :auto_track, :tracking_method,
          tracking_criteria: []
        )
      end
    end
  end
end
