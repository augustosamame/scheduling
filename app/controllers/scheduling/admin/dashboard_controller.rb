module Scheduling
  module Admin
    class DashboardController < BaseController
      def index
        @bookings = scope_bookings
                    .includes(:client, :member, :event_type, :payment)
                    .order(start_time: :desc)

        # Apply filters
        @bookings = filter_by_status(@bookings)
        @bookings = filter_by_date_range(@bookings)
        @bookings = filter_by_location(@bookings)
        @bookings = filter_by_team(@bookings)
        @bookings = filter_by_member(@bookings)
        @bookings = filter_by_payment_status(@bookings)
        @bookings = search_bookings(@bookings)

        # Apply pagination if Kaminari is available
        if @bookings.respond_to?(:page)
          @bookings = @bookings.page(params[:page]).per(20)
        else
          # Limit to 50 results if no pagination
          @bookings = @bookings.limit(50)
        end

        # Statistics for dashboard
        @stats = calculate_statistics

        # Data for filter dropdowns
        @locations = Location.order(:name)
        @teams = Team.order(:name)
        @members = Member.where(accepts_bookings: true)
                         .joins(:user)
                         .order('users.first_name, users.last_name')
      end

      private

      def filter_by_status(bookings)
        return bookings unless params[:status].present?
        bookings.where(status: params[:status])
      end

      def filter_by_date_range(bookings)
        if params[:date_from].present?
          bookings = bookings.where('start_time >= ?', Date.parse(params[:date_from]).beginning_of_day)
        end

        if params[:date_to].present?
          bookings = bookings.where('start_time <= ?', Date.parse(params[:date_to]).end_of_day)
        end

        bookings
      end

      def filter_by_location(bookings)
        return bookings unless params[:location_id].present?
        bookings.joins(member: :location).where(scheduling_locations: { id: params[:location_id] })
      end

      def filter_by_team(bookings)
        return bookings unless params[:team_id].present?
        bookings.joins(member: :team).where(scheduling_teams: { id: params[:team_id] })
      end

      def filter_by_member(bookings)
        return bookings unless params[:member_id].present?
        bookings.where(member_id: params[:member_id])
      end

      def filter_by_payment_status(bookings)
        return bookings unless params[:payment_status].present?
        bookings.where(payment_status: params[:payment_status])
      end

      def search_bookings(bookings)
        return bookings unless params[:q].present?

        query = "%#{params[:q]}%"
        bookings.joins(:client).where(
          "scheduling_clients.first_name ILIKE ? OR scheduling_clients.last_name ILIKE ? OR scheduling_clients.email ILIKE ?",
          query, query, query
        )
      end

      def calculate_statistics
        base_scope = scope_bookings

        {
          total: base_scope.count,
          confirmed: base_scope.where(status: 'confirmed').count,
          cancelled: base_scope.where(status: 'cancelled').count,
          completed: base_scope.where(status: 'completed').count,
          pending_payment: base_scope.where(payment_status: 'pending').count,
          upcoming: base_scope.where(status: 'confirmed').where('start_time > ?', Time.current).count,
          today: base_scope.where(status: 'confirmed').where('DATE(start_time) = ?', Date.current).count
        }
      end
    end
  end
end
