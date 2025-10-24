class CreateSchedulingCalendarConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_calendar_connections do |t|
      t.references :member, null: false, foreign_key: { to_table: :scheduling_members }
      t.string :provider, null: false # google, outlook
      t.string :external_calendar_id
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.boolean :check_for_conflicts, default: true
      t.boolean :add_bookings_to_calendar, default: true
      t.boolean :active, default: true

      t.timestamps

      t.index [:member_id, :provider], unique: true
    end
  end
end
