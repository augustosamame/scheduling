module Scheduling
  module Admin
    class LocationsController < BaseController
      before_action :set_location, only: [:show, :edit, :update, :destroy]
      before_action :require_admin_role

      def index
        @locations = Location.includes(:organization, :teams, :members)
                            .order('scheduling_organizations.name', 'scheduling_locations.name')

        if params[:status] == 'active'
          @locations = @locations.where(active: true)
        elsif params[:status] == 'inactive'
          @locations = @locations.where(active: false)
        end

        if @locations.respond_to?(:page)
          @locations = @locations.page(params[:page]).per(20)
        else
          @locations = @locations.limit(50)
        end
      end

      def show
        @teams = @location.teams.includes(:members).order(:name).limit(10)
      end

      def new
        @location = Location.new(active: true, timezone: 'Lima')
        load_form_data
      end

      def create
        @location = Location.new(location_params)

        if @location.save
          redirect_to admin_location_path(@location), notice: t('scheduling.admin.locations.create.success')
        else
          load_form_data
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        load_form_data
      end

      def update
        if @location.update(location_params)
          redirect_to admin_location_path(@location), notice: t('scheduling.admin.locations.update.success')
        else
          load_form_data
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @location.destroy
        redirect_to admin_locations_path, notice: t('scheduling.admin.locations.destroy.success')
      rescue StandardError => e
        redirect_to admin_locations_path, alert: t('scheduling.admin.locations.destroy.error', error: e.message)
      end

      private

      def set_location
        # Support both integer IDs and slugs
        @location = if params[:id].to_i.to_s == params[:id]
                      Location.find(params[:id])
                    else
                      Location.find_by!(slug: params[:id])
                    end
      end

      def require_admin_role
        unless @current_member.admin?
          redirect_to admin_root_path, alert: t('scheduling.admin.errors.unauthorized')
        end
      end

      def load_form_data
        @organizations = Organization.order(:name)
      end

      def location_params
        params.require(:location).permit(
          :name,
          :slug,
          :organization_id,
          :timezone,
          :address,
          :city,
          :state,
          :postal_code,
          :country,
          :active
        )
      end
    end
  end
end
