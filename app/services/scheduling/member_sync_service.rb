module Scheduling
  class MemberSyncService
    def initialize(user)
      @user = user
      @config = Scheduling.configuration
    end

    def sync
      return unless should_sync?

      organization = ensure_organization
      location = ensure_location(organization)
      team = ensure_team(location)
      ensure_member(team)
    end

    private

    def should_sync?
      @config.auto_create_members && @user.persisted?
    end

    def ensure_organization
      Organization.find_or_create_by!(slug: @config.organization_slug) do |org|
        org.name = @config.organization_name
        org.timezone = @config.organization_timezone
        org.default_currency = @config.organization_currency
        org.default_locale = @config.organization_locale
      end
    end

    def ensure_location(organization)
      # Try to get location from user if association exists
      if @user.respond_to?(:location) && @user.location.present?
        # User has a location association, find or create corresponding scheduling location
        user_location = @user.location

        organization.locations.find_or_create_by!(
          name: user_location.respond_to?(:name) ? user_location.name : @config.default_location_name
        ) do |loc|
          loc.slug = user_location.respond_to?(:name) ? user_location.name.parameterize : 'default'
          loc.timezone = @config.organization_timezone
          loc.city = user_location.respond_to?(:city) ? user_location.city : nil
          loc.country = user_location.respond_to?(:country) ? user_location.country : nil
        end
      else
        # No location association, use default
        organization.locations.find_or_create_by!(
          slug: 'sede-principal'
        ) do |loc|
          loc.name = @config.default_location_name
          loc.timezone = @config.organization_timezone
        end
      end
    end

    def ensure_team(location)
      # Try to get team from user if association exists
      if @user.respond_to?(:team) && @user.team.present?
        # User has a team association, find or create corresponding scheduling team
        user_team = @user.team

        location.teams.find_or_create_by!(
          name: user_team.respond_to?(:name) ? user_team.name : @config.default_team_name
        ) do |t|
          t.slug = user_team.respond_to?(:name) ? user_team.name.parameterize : 'default'
          t.description = user_team.respond_to?(:description) ? user_team.description : nil
          t.color = '#3b82f6'
        end
      else
        # No team association, use default
        location.teams.find_or_create_by!(
          slug: 'equipo-por-defecto'
        ) do |t|
          t.name = @config.default_team_name
          t.description = 'Equipo por defecto para miembros sin equipo asignado'
          t.color = '#6b7280'
        end
      end
    end

    def ensure_member(team)
      member = team.members.find_or_initialize_by(user: @user)

      if member.new_record?
        member.assign_attributes(
          role: determine_role,
          active: true,
          accepts_bookings: should_accept_bookings?
        )
        member.save!
      elsif @config.sync_member_on_user_update
        # Update member if user changed (name might affect booking_slug)
        # Note: booking_slug should remain stable, so we don't regenerate it
        member.touch # Just update timestamp to indicate sync happened
      end

      member
    end

    def determine_role
      # Check if user has a role attribute
      if @user.respond_to?(:role)
        case @user.role.to_s.downcase
        when 'admin', 'administrator'
          'admin'
        when 'manager'
          'manager'
        else
          'member'
        end
      else
        'member' # Default role
      end
    end

    def should_accept_bookings?
      # Check if user should accept bookings
      # Could be based on user role, type, or explicit attribute
      if @user.respond_to?(:accepts_bookings)
        @user.accepts_bookings
      elsif @user.respond_to?(:role)
        # Doctors, providers, etc. should accept bookings
        %w[doctor provider practitioner therapist].any? { |r| @user.role.to_s.downcase.include?(r) }
      else
        true # Default to accepting bookings
      end
    end
  end
end
