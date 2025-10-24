# This migration comes from scheduling (originally 20241024000004)
class CreateSchedulingBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_bookings do |t|
      t.references :event_type, null: false, foreign_key: { to_table: :scheduling_event_types }
      t.references :member, null: false, foreign_key: { to_table: :scheduling_members }
      t.references :client, null: false, foreign_key: { to_table: :scheduling_clients }

      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :timezone, null: false

      t.string :status, default: 'confirmed' # confirmed, cancelled, rescheduled, completed, no_show
      t.string :cancellation_reason
      t.text :notes

      t.string :uid, null: false # Unique identifier for iCal
      t.string :reschedule_token
      t.string :cancellation_token
      t.references :rescheduled_from, foreign_key: { to_table: :scheduling_bookings }

      # Payment
      t.string :payment_status, default: 'not_required' # not_required, pending, paid, failed, refunded

      # External calendar IDs
      t.string :google_calendar_event_id
      t.string :outlook_calendar_event_id

      t.string :locale, default: 'es'
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index :uid, unique: true
      t.index :reschedule_token, unique: true
      t.index :cancellation_token, unique: true
      t.index [:member_id, :start_time]
      t.index [:client_id, :start_time]
      t.index :status
      t.index :payment_status
    end

    create_table :scheduling_booking_changes do |t|
      t.references :booking, null: false, foreign_key: { to_table: :scheduling_bookings }
      t.string :change_type, null: false # cancelled, rescheduled, completed, no_show
      t.datetime :old_start_time
      t.datetime :old_end_time
      t.datetime :new_start_time
      t.datetime :new_end_time
      t.text :reason
      t.string :initiated_by # client, member, system

      t.timestamps

      t.index [:booking_id, :change_type]
      t.index :created_at
    end
  end
end
