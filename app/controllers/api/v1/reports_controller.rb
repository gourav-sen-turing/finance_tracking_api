module Api
  module V1
    class ReportsController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_date_parameters

      # GET /api/v1/reports/monthly_summary
      def monthly_summary
        report_service = Reports::MonthlySummaryService.new(current_user, report_params)
        report_data = report_service.cached_generate

        render json: report_data
      end

      # GET /api/v1/reports/category_breakdown
      def category_breakdown
        report_service = Reports::CategoryBreakdownService.new(current_user, report_params)
        report_data = report_service.cached_generate

        render json: report_data
      end

      # GET /api/v1/reports/income_expense_analysis
      def income_expense_analysis
        report_service = Reports::IncomeExpenseService.new(current_user, report_params)
        report_data = report_service.cached_generate

        render json: report_data
      end

      # GET /api/v1/reports/trend_analysis
      def trend_analysis
        report_service = Reports::TrendAnalysisService.new(current_user, report_params)
        report_data = report_service.cached_generate

        render json: report_data
      end

      # GET /api/v1/reports/financial_health
      def financial_health
        report_service = Reports::FinancialHealthService.new(current_user, report_params)
        report_data = report_service.cached_generate

        render json: report_data
      end

      private

      def report_params
        params.permit(
          :year, :month, :start_date, :end_date, :period,
          :include_details, :group_by, :category_id
        )
      end

      def validate_date_parameters
        if params[:start_date].present? && params[:end_date].present?
          begin
            start_date = Date.parse(params[:start_date])
            end_date = Date.parse(params[:end_date])

            if start_date > end_date
              return render_date_error("Start date cannot be after end date")
            end

            if (end_date - start_date).to_i > 366
              return render_date_error("Date range cannot exceed one year")
            end
          rescue ArgumentError => e
            return render_date_error("Invalid date format: #{e.message}")
          end
        end

        if params[:year].present? && params[:month].present?
          year = params[:year].to_i
          month = params[:month].to_i

          unless (1..12).include?(month) && year > 2000 && year < 2100
            return render_date_error("Invalid year or month values")
          end
        end
      end

      def render_date_error(message)
        render json: { error: message }, status: :bad_request
      end
    end
  end
end
