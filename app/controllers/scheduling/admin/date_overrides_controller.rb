module Scheduling
  module Admin
    class DateOverridesController < BaseController
      before_action :set_date_override, only: [:show, :edit, :update, :destroy]
      before_action :authorize_manage_date_override, only: [:edit, :update, :destroy]

      def index
        @date_overrides = scope_date_overrides
                          .includes(:member)
                          .order(date: :asc)

        # Filter by date range
        if params[:date_from].present?
          @date_overrides = @date_overrides.where('date >= ?', params[:date_from])
        end
        if params[:date_to].present?
          @date_overrides = @date_overrides.where('date <= ?', params[:date_to])
        end

        # Filter by type (available/unavailable)
        if params[:override_type].present?
          if params[:override_type] == 'unavailable'
            @date_overrides = @date_overrides.where(unavailable: true)
          elsif params[:override_type] == 'available'
            @date_overrides = @date_overrides.where(unavailable: false)
          end
        end

        # Apply pagination if Kaminari is available
        if @date_overrides.respond_to?(:page)
          @date_overrides = @date_overrides.page(params[:page]).per(20)
        else
          @date_overrides = @date_overrides.limit(50)
        end
      end

      def show
        authorize_manage_date_override!(@date_override)
      end

      def new
        @date_override = @current_member.date_overrides.build(
          date: params[:date] || Date.tomorrow
        )
      end

      def create
        @date_override = @current_member.date_overrides.build(date_override_params)

        if @date_override.save
          redirect_to admin_date_overrides_path, notice: t('scheduling.admin.date_overrides.create.success')
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        # Render edit form
      end

      def update
        if @date_override.update(date_override_params)
          redirect_to admin_date_overrides_path, notice: t('scheduling.admin.date_overrides.update.success')
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @date_override.destroy
        redirect_to admin_date_overrides_path, notice: t('scheduling.admin.date_overrides.destroy.success')
      rescue StandardError => e
        redirect_to admin_date_overrides_path, alert: t('scheduling.admin.date_overrides.destroy.error', error: e.message)
      end

      private

      def set_date_override
        @date_override = scope_date_overrides.find(params[:id])
      end

      def authorize_manage_date_override
        authorize_manage_date_override!(@date_override)
      end

      def authorize_manage_date_override!(date_override)
        # Admins can manage all date overrides, managers/members can only manage their own
        unless @current_member.admin? || date_override.member_id == @current_member.id
          redirect_to admin_date_overrides_path, alert: t('scheduling.admin.errors.unauthorized')
        end
      end

      def scope_date_overrides
        # Admins see all date overrides, others see only their own
        if @current_member.admin?
          DateOverride.all
        else
          @current_member.date_overrides
        end
      end

      def date_override_params
        params.require(:date_override).permit(
          :date,
          :reason,
          :unavailable,
          :start_time,
          :end_time
        )
      end
    end
  end
end
