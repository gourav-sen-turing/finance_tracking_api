module Api
  module V1
    module Auth
      class AuthenticationController < ApplicationController
        # Skip authentication for the login endpoint
        # skip_before_action :authorize_request, only: :authenticate

        # POST /api/v1/auth/login
        # Return auth token once user is authenticated
        def authenticate
          byebug
          auth_service = AuthenticateUser.new(auth_params[:email], auth_params[:password])
          auth_token = auth_service.call[:result]

          user = User.find_by(email: auth_params[:email])

          response = {
            data: {
              token: auth_token,
              user: UserSerializer.new(user).serializable_hash[:data][:attributes]
            },
            message: 'Login successful'
          }

          render json: response
        end

        def logout
          # Extract the JWT token from the Authorization header
          auth_header = request.headers['Authorization']

          if auth_header.present?
            token = auth_header.split(' ').last
            if TokenBlacklist.add(token)
              # Successfully blacklisted
              head :no_content
            else
              # Failed to blacklist
              render json: { error: 'Logout failed' }, status: :internal_server_error
            end
          else
            # No token provided
            head :no_content
          end
        end

        private

        def auth_params
          params.permit(:email, :password)
        end
      end
    end
  end
end
