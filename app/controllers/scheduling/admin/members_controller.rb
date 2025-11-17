module Scheduling
  module Admin
    class MembersController < BaseController
      before_action :set_member, only: [:show, :edit, :update, :destroy]
      before_action :require_manager_role

      def index
        @members = scope_members
                   .includes(:user, :team, :location, :organization)
                   .order('users.first_name, users.last_name')

        # Filter by team
        if params[:team_id].present?
          @members = @members.where(team_id: params[:team_id])
        end

        # Filter by location
        if params[:location_id].present?
          @members = @members.joins(:team).where(scheduling_teams: { location_id: params[:location_id] })
        end

        # Filter by role
        if params[:role].present? && params[:role] != 'all'
          @members = @members.where(role: params[:role])
        end

        # Filter by status
        if params[:status] == 'active'
          @members = @members.where(active: true)
        elsif params[:status] == 'inactive'
          @members = @members.where(active: false)
        end

        # Apply pagination if Kaminari is available
        if @members.respond_to?(:page)
          @members = @members.page(params[:page]).per(20)
        else
          @members = @members.limit(50)
        end

        # Data for filters
        @teams = Team.order(:name)
        @locations = Location.order(:name)
      end

      def show
        @schedules = @member.schedules.order(is_default: :desc, created_at: :desc).limit(5)
        @event_types = @member.event_types.order(:title).limit(5)
        @upcoming_bookings = @member.bookings.where('start_time > ?', Time.current).order(:start_time).limit(5)
      end

      def new
        @member = Member.new(
          role: 'member',
          active: true,
          accepts_bookings: true
        )
        load_form_data
      end

      def create
        @member = Member.new(member_params)

        if @member.save
          redirect_to admin_member_path(@member), notice: t('scheduling.admin.members.create.success')
        else
          load_form_data
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        load_form_data
      end

      def update
        if @member.update(member_params)
          redirect_to admin_member_path(@member), notice: t('scheduling.admin.members.update.success')
        else
          load_form_data
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @member.destroy
        redirect_to admin_members_path, notice: t('scheduling.admin.members.destroy.success')
      rescue StandardError => e
        redirect_to admin_members_path, alert: t('scheduling.admin.members.destroy.error', error: e.message)
      end

      private

      def set_member
        # Support both integer IDs and booking slugs
        @member = if params[:id].to_i.to_s == params[:id]
                    scope_members.find(params[:id])
                  else
                    scope_members.find_by!(booking_slug: params[:id])
                  end
      end

      def require_manager_role
        unless @current_member.manager?
          redirect_to admin_root_path, alert: t('scheduling.admin.errors.unauthorized')
        end
      end

      def scope_members
        # Admins see all members, managers see members in their location
        if @current_member.admin?
          Member.all
        else
          Member.where(team: @current_member.location.teams)
        end
      end

      def load_form_data
        @teams = Team.includes(:location).order('scheduling_locations.name', 'scheduling_teams.name')
        @users = User.order(:first_name, :last_name)
      end

      def member_params
        params.require(:member).permit(
          :user_id,
          :team_id,
          :role,
          :booking_slug,
          :active,
          :accepts_bookings
        )
      end
    end
  end
end
