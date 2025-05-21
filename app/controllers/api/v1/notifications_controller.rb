module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_notification, only: [:show, :mark_as_read, :archive]

      # GET /api/v1/notifications
      def index
        @notifications = current_user.notifications

        # Apply status filter
        status = params[:status] || 'unread'
        @notifications = @notifications.where(status: status) if %w[unread read archived].include?(status)

        # Apply category filter
        if params[:category].present?
          @notifications = @notifications.joins(:notification_type)
                             .where(notification_types: { category: params[:category] })
        end

        # Apply date range filter
        if params[:start_date].present? && params[:end_date].present?
          begin
            start_date = Date.parse(params[:start_date])
            end_date = Date.parse(params[:end_date])
            @notifications = @notifications.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          rescue ArgumentError
            # Invalid date format, ignore filter
          end
        end

        # Sort by date (newest first)
        @notifications = @notifications.order(created_at: :desc)

        # Pagination
        @notifications = @notifications.page(params[:page] || 1).per(params[:per_page] || 20)

        render json: {
          notifications: @notifications.as_json(
            include: { notification_type: { only: [:id, :code, :name, :category, :icon] } },
            methods: []
          ),
          pagination: {
            total_pages: @notifications.total_pages,
            current_page: @notifications.current_page,
            total_count: @notifications.total_count
          },
          unread_count: current_user.notifications.unread.count
        }
      end

      # GET /api/v1/notifications/1
      def show
        # Mark as read when viewed
        @notification.mark_as_read! if @notification.status == 'unread'

        render json: {
          notification: @notification.as_json(
            include: {
              notification_type: { only: [:id, :code, :name, :category, :icon] },
              source: { only: [:id, :type] }
            }
          )
        }
      end

      # POST /api/v1/notifications/mark_all_as_read
      def mark_all_as_read
        current_user.notifications.unread.update_all(
          status: 'read',
          read_at: Time.current
        )

        render json: {
          message: 'All notifications marked as read',
          unread_count: 0
        }
      end

      # PATCH /api/v1/notifications/1/mark_as_read
      def mark_as_read
        @notification.mark_as_read!

        render json: {
          message: 'Notification marked as read',
          unread_count: current_user.notifications.unread.count
        }
      end

      # PATCH /api/v1/notifications/1/archive
      def archive
        @notification.archive!

        render json: {
          message: 'Notification archived',
          unread_count: current_user.notifications.unread.count
        }
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        render json: {
          unread_count: current_user.notifications.unread.count
        }
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Notification not found' }, status: :not_found
      end
    end
  end
end
