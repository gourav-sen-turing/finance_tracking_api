module Api
  module V1
    module Auth
      class UsersController < ApplicationController
        # Skip authentication for the signup endpoint
        skip_before_action :authorize_request, only: :create

        # POST /api/v1/auth/signup
        # Create a new user and return auth token
        def create
          ActiveRecord::Base.transaction do
            user = User.create!(user_params)

            begin
              auth_service = AuthenticateUser.new(user.email, user.password)
              auth_token = auth_service.call[:result]

              response = {
                data: {
                  token: auth_token,
                  user: UserSerializer.new(user).serializable_hash[:data][:attributes]
                },
                message: 'Account created successfully'
              }

              render json: response, status: :created
            rescue ExceptionHandler::AuthenticationError => e
              # Rollback the user creation if authentication fails
              raise ActiveRecord::Rollback
              render json: { error: e.message }, status: :unprocessable_entity
            end
          end
        end


        private

        def user_params
          # Make sure this includes first_name and last_name, not name
          params.permit(
            :first_name,
            :last_name,
            :email,
            :password,
            :password_confirmation
          )
        end
      end
    end
  end
end
