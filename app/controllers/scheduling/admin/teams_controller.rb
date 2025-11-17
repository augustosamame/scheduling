module Scheduling
  module Admin
    class TeamsController < BaseController
      before_action :set_team, only: [:show, :edit, :update, :destroy]
      before_action :require_manager_role

      def index
        @teams = scope_teams
                 .includes(:location, :organization, :members)
                 .order('scheduling_locations.name', 'scheduling_teams.name')

        # Filter by location
        if params[:location_id].present?
          @teams = @teams.where(location_id: params[:location_id])
        end

        # Filter by status
        if params[:status] == 'active'
          @teams = @teams.where(active: true)
        elsif params[:status] == 'inactive'
          @teams = @teams.where(active: false)
        end

        # Apply pagination if Kaminari is available
        if @teams.respond_to?(:page)
          @teams = @teams.page(params[:page]).per(20)
        else
          @teams = @teams.limit(50)
        end

        # Data for filters
        @locations = Location.order(:name)
      end

      def show
        @members = @team.members.includes(:user).order('users.first_name, users.last_name').limit(10)
      end

      def new
        @team = Team.new(active: true, color: '#3B82F6')
        load_form_data
      end

      def create
        @team = Team.new(team_params)

        if @team.save
          redirect_to admin_team_path(@team), notice: t('scheduling.admin.teams.create.success')
        else
          load_form_data
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        load_form_data
      end

      def update
        if @team.update(team_params)
          redirect_to admin_team_path(@team), notice: t('scheduling.admin.teams.update.success')
        else
          load_form_data
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @team.destroy
        redirect_to admin_teams_path, notice: t('scheduling.admin.teams.destroy.success')
      rescue StandardError => e
        redirect_to admin_teams_path, alert: t('scheduling.admin.teams.destroy.error', error: e.message)
      end

      private

      def set_team
        # Support both integer IDs and slugs
        @team = if params[:id].to_i.to_s == params[:id]
                  scope_teams.find(params[:id])
                else
                  scope_teams.find_by!(slug: params[:id])
                end
      end

      def require_manager_role
        unless @current_member.manager?
          redirect_to admin_root_path, alert: t('scheduling.admin.errors.unauthorized')
        end
      end

      def scope_teams
        # Admins see all teams, managers see teams in their location
        if @current_member.admin?
          Team.all
        else
          @current_member.location.teams
        end
      end

      def load_form_data
        @locations = Location.order(:name)
      end

      def team_params
        params.require(:team).permit(
          :name,
          :slug,
          :location_id,
          :color,
          :active,
          :description
        )
      end
    end
  end
end
