module Scheduling
  module UserExtensions
    extend ActiveSupport::Concern

    included do
      has_many :scheduling_members, class_name: 'Scheduling::Member', dependent: :destroy

      after_commit :sync_scheduling_member, on: [:create, :update], if: :should_sync_scheduling?
    end

    private

    def should_sync_scheduling?
      return false unless Scheduling.configuration.auto_create_members

      # On create (after_commit), check if this was a new record
      if previously_new_record?
        first_name.present? && last_name.present?
      else
        # On update, only sync if relevant fields changed
        saved_change_to_first_name? || saved_change_to_last_name? ||
          saved_change_to_attribute?(:location_id) || saved_change_to_attribute?(:team_id)
      end
    end

    def sync_scheduling_member
      Scheduling::MemberSyncService.new(self).sync
    rescue StandardError => e
      Rails.logger.error "Failed to sync scheduling member for user #{id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't raise - we don't want to break user creation/update if scheduling sync fails
    end
  end
end
