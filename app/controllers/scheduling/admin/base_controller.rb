module Scheduling
  module Admin
    class BaseController < ApplicationController
      before_action :set_admin_locale
      before_action :authenticate_user!
      before_action :set_current_member
      before_action :authorize_admin_access!

      layout 'scheduling/admin'

      helper_method :current_member, :admin?, :manager?, :member_user?

      private

      def set_admin_locale
        # Admin panel supports only Spanish and English
        # Default to Spanish
        available_locales = [:es, :en]
        requested_locale = params[:locale]&.to_sym || session[:admin_locale]&.to_sym || :es

        I18n.locale = if available_locales.include?(requested_locale)
                       session[:admin_locale] = requested_locale
                       requested_locale
                     else
                       session[:admin_locale] = :es
                       :es
                     end
      end

      def authenticate_user!
        # This method should be implemented in the host application
        # It should redirect to login if user is not authenticated
        unless respond_to?(:current_user) && current_user
          redirect_to main_app.root_path, alert: "Please log in to access this page"
        end
      end

      def set_current_member
        @current_member = Member.find_by(user: current_user) if current_user

        unless @current_member
          redirect_to main_app.root_path, alert: "No scheduling member found for your account"
        end
      end

      def current_member
        @current_member
      end

      def authorize_admin_access!
        unless @current_member && ['admin', 'manager', 'member'].include?(@current_member.role)
          redirect_to main_app.root_path, alert: "You don't have permission to access this page"
        end
      end

      def admin?
        @current_member&.role == 'admin'
      end

      def manager?
        @current_member&.role == 'manager'
      end

      def member_user?
        @current_member&.role == 'member'
      end

      # Authorization helpers for specific resources
      def authorize_manage_booking!(booking)
        return if admin? # Admins can manage all bookings
        return if manager? && booking.member.team.location == @current_member.team.location # Managers can manage their location
        return if member_user? && booking.member == @current_member # Members can manage their own bookings

        redirect_to admin_root_path, alert: "You don't have permission to manage this booking"
      end

      def authorize_manage_event_type!(event_type)
        return if admin? # Admins can manage all event types
        return if manager? && event_type.member.team.location == @current_member.team.location # Managers can manage their location
        return if member_user? && event_type.member == @current_member # Members can manage their own event types

        redirect_to admin_root_path, alert: "You don't have permission to manage this event type"
      end

      def scope_bookings
        if admin?
          # Admins see all bookings in their organization
          organization = @current_member.team.location.organization
          Booking.joins(member: { team: { location: :organization } }).where(scheduling_organizations: { id: organization.id })
        elsif manager?
          # Managers see bookings for their location
          location = @current_member.team.location
          Booking.joins(member: { team: :location }).where(scheduling_locations: { id: location.id })
        else
          # Members see only their own bookings
          @current_member.bookings
        end
      end

      def scope_event_types
        if admin?
          # Admins see all event types in their organization
          organization = @current_member.team.location.organization
          EventType.joins(member: { team: { location: :organization } }).where(scheduling_organizations: { id: organization.id })
        elsif manager?
          # Managers see event types for their location
          location = @current_member.team.location
          EventType.joins(member: { team: :location }).where(scheduling_locations: { id: location.id })
        else
          # Members see only their own event types
          @current_member.event_types
        end
      end
    end
  end
end
