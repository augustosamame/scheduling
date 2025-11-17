module Scheduling
  module Admin
    class EventTypesController < BaseController
      before_action :set_event_type, only: [:show, :edit, :update, :destroy]
      before_action :authorize_manage_event_type, only: [:edit, :update, :destroy]

      def index
        @event_types = scope_event_types
                       .includes(:member)
                       .order(created_at: :desc)

        # Apply pagination if Kaminari is available
        if @event_types.respond_to?(:page)
          @event_types = @event_types.page(params[:page]).per(20)
        else
          # Limit to 50 results if no pagination
          @event_types = @event_types.limit(50)
        end
      end

      def show
        authorize_manage_event_type!(@event_type)
      end

      def new
        @event_type = @current_member.event_types.build
      end

      def create
        @event_type = @current_member.event_types.build(event_type_params)

        if @event_type.save
          redirect_to admin_event_type_path(@event_type), notice: "Event type created successfully"
        else
          render :new
        end
      end

      def edit
        # Render edit form
      end

      def update
        if @event_type.update(event_type_params)
          redirect_to admin_event_type_path(@event_type), notice: "Event type updated successfully"
        else
          render :edit
        end
      end

      def destroy
        @event_type.destroy
        redirect_to admin_event_types_path, notice: "Event type deleted successfully"
      rescue StandardError => e
        redirect_to admin_event_types_path, alert: "Error deleting event type: #{e.message}"
      end

      private

      def set_event_type
        @event_type = scope_event_types.find_by!(slug: params[:id])
      end

      def authorize_manage_event_type
        authorize_manage_event_type!(@event_type)
      end

      def event_type_params
        params.require(:event_type).permit(
          :title,
          :slug,
          :description,
          :duration_minutes,
          :buffer_before_minutes,
          :buffer_after_minutes,
          :minimum_notice_hours,
          :maximum_days_in_future,
          :location_type,
          :location_details,
          :color,
          :active,
          :requires_payment,
          :payment_required_to_book,
          :price_cents,
          :price_currency,
          :allow_cancellation,
          :cancellation_policy_hours,
          :allow_rescheduling,
          :rescheduling_policy_hours,
          :slots_per_time_slot,
          :metadata
        )
      end
    end
  end
end
