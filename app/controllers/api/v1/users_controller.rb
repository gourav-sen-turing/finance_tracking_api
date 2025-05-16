module Api
  module V1
    class UsersController < ApplicationController
      before_action :set_user, only: [:show, :update, :destroy]

      # GET /api/v1/users/:id
      def show
        render json: UserSerializer.new(@user).serializable_hash
      end

      # GET /api/v1/users/me
      def me
        render json: UserSerializer.new(current_user).serializable_hash
      end

      # PATCH/PUT /api/v1/users/:id
      def update
        # Only allow users to update their own profile
        if @user.id != current_user.id
          return render json: { error: 'Unauthorized' }, status: :unauthorized
        end

        if @user.update(user_params)
          render json: UserSerializer.new(@user).serializable_hash
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        # Only allow users to delete their own account
        if @user.id != current_user.id
          return render json: { error: 'Unauthorized' }, status: :unauthorized
        end

        @user.destroy
        head :no_content
      end

      private

      def set_user
        @user = params[:id] == 'me' ? current_user : User.find(params[:id])
      end

      def user_params
        params.permit(:first_name, :email, :password, :password_confirmation)
      end
    end
  end
end
