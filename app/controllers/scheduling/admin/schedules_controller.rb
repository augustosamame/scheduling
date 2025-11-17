module Scheduling
  module Admin
    class SchedulesController < BaseController
      before_action :set_schedule, only: [:show, :edit, :update, :destroy]
      before_action :authorize_manage_schedule, only: [:edit, :update, :destroy]

      def index
        @schedules = scope_schedules
                     .includes(:member, :availabilities)
                     .order(is_default: :desc, created_at: :desc)

        # Apply pagination if Kaminari is available
        if @schedules.respond_to?(:page)
          @schedules = @schedules.page(params[:page]).per(20)
        else
          @schedules = @schedules.limit(50)
        end
      end

      def show
        authorize_manage_schedule!(@schedule)
      end

      def new
        @schedule = @current_member.schedules.build(
          timezone: 'America/Lima'
        )

        # Build default availabilities (Mon-Fri 9am-5pm)
        (1..5).each do |day|
          @schedule.availabilities.build(
            day_of_week: day,
            start_time: '09:00',
            end_time: '17:00'
          )
        end
      end

      def create
        @schedule = @current_member.schedules.build(schedule_params)

        if @schedule.save
          redirect_to admin_schedule_path(@schedule), notice: t('scheduling.admin.schedules.create.success')
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        # Ensure all days have at least one availability slot for editing
        (0..6).each do |day|
          unless @schedule.availabilities.exists?(day_of_week: day)
            @schedule.availabilities.build(day_of_week: day)
          end
        end
      end

      def update
        if @schedule.update(schedule_params)
          redirect_to admin_schedule_path(@schedule), notice: t('scheduling.admin.schedules.update.success')
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @schedule.destroy
        redirect_to admin_schedules_path, notice: t('scheduling.admin.schedules.destroy.success')
      rescue StandardError => e
        redirect_to admin_schedules_path, alert: t('scheduling.admin.schedules.destroy.error', error: e.message)
      end

      private

      def set_schedule
        @schedule = scope_schedules.find(params[:id])
      end

      def authorize_manage_schedule
        authorize_manage_schedule!(@schedule)
      end

      def authorize_manage_schedule!(schedule)
        # Admins can manage all schedules, managers/members can only manage their own
        unless @current_member.admin? || schedule.member_id == @current_member.id
          redirect_to admin_schedules_path, alert: t('scheduling.admin.errors.unauthorized')
        end
      end

      def scope_schedules
        # Admins see all schedules, others see only their own
        if @current_member.admin?
          Schedule.all
        else
          @current_member.schedules
        end
      end

      def schedule_params
        params.require(:schedule).permit(
          :name,
          :timezone,
          :is_default,
          availabilities_attributes: [
            :id,
            :day_of_week,
            :start_time,
            :end_time,
            :_destroy
          ]
        )
      end
    end
  end
end
