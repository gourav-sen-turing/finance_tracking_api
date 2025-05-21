module Api
  module V1
    class NotificationPreferencesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_preference, only: [:update]

      # GET /api/v1/notification_preferences
      def index
        @preferences = current_user.notification_preferences.includes(:notification_type)

        render json: {
          notification_preferences: @preferences.as_json(
            include: { notification_type: { only: [:id, :code, :name, :category, :description, :icon] } }
          )
        }
      end

      # PATCH /api/v1/notification_preferences/1
      def update
        if @preference.update(preference_params)
          render json: {
            notification_preference: @preference.as_json(
              include: { notification_type: { only: [:id, :code, :name, :category, :description, :icon] } }
            )
          }
        else
          render json: { errors: @preference.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/notification_preferences/update_all
      def update_all
        # Mass update all preferences (e.g., disabling all emails)
        if params[:update_type].present? && params[:value].present?
          field = case params[:update_type]
                  when 'email'
                    'email_enabled'
                  when 'push'
                    'push_enabled'
                  when 'in_app'
                    'in_app_enabled'
                  end

          if field.present?
            bool_value = params[:value].to_s.downcase == 'true'
            current_user.notification_preferences.update_all(field => bool_value)

            render json: {
              message: "All #{params[:update_type]} notifications #{bool_value ? 'enabled' : 'disabled'}"
            }
            return
          end
        end

        render json: { error: 'Invalid update parameters' }, status: :bad_request
      end

      private

      def set_preference
        @preference = current_user.notification_preferences.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Notification preference not found' }, status: :not_found
      end

      def preference_params
        params.require(:notification_preference).permit(
          :email_enabled, :push_enabled, :in_app_enabled,
          :threshold_value, :threshold_unit
        )
      end
    end
  end
end
