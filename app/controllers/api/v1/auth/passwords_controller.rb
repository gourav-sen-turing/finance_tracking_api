module Api
  module V1
    module Auth
      class PasswordsController < ApplicationController
        # Skip authentication for password reset endpoints
        skip_before_action :authorize_request

        # POST /api/v1/auth/password/forgot
        def forgot
          # Validate request contains email
          return render json: { error: 'Email is required' }, status: :bad_request unless params[:email].present?

          # Find the user by email
          @user = User.find_by(email: params[:email].downcase)

          if @user.present?
            # Generate and store a reset token
            token = @user.generate_password_reset_token!

            # In a real application, you'd send an email here
            # PasswordMailer.with(user: @user, token: token).reset_password.deliver_now

            # For development purposes, return the token in the response
            # In production, you'd just acknowledge the request was received
            render json: {
              message: 'Password reset instructions sent to email',
              # Remove this line in production
              token: token
            }, status: :ok
          else
            # For security reasons, don't reveal if a user was found or not
            render json: {
              message: 'If your email exists in our database, you will receive password reset instructions'
            }, status: :ok
          end
        end

        # POST /api/v1/auth/password/reset
        def reset
          # Validate request parameters
          unless params[:token].present? && params[:password].present? && params[:password_confirmation].present?
            return render json: { error: 'Token, password, and password confirmation are required' }, status: :bad_request
          end

          # Validate password and confirmation match
          unless params[:password] == params[:password_confirmation]
            return render json: { error: 'Password and confirmation do not match' }, status: :unprocessable_entity
          end

          # Find user by reset token
          @user = User.find_by(reset_password_token: params[:token])

          if @user.present? && @user.password_reset_token_valid?
            # Update the password
            if @user.update(password: params[:password])
              # Clear the reset token after successful password update
              @user.clear_password_reset_token!

              # Return success response
              render json: {
                message: 'Password has been reset successfully'
              }, status: :ok
            else
              # Return validation errors if any
              render json: {
                error: 'Password reset failed',
                details: @user.errors.full_messages
              }, status: :unprocessable_entity
            end
          else
            # Invalid or expired token
            render json: {
              error: 'Invalid or expired token'
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
