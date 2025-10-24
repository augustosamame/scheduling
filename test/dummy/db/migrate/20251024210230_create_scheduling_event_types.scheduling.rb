# This migration comes from scheduling (originally 20241024000002)
class CreateSchedulingEventTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_event_types do |t|
      t.references :member, null: false, foreign_key: { to_table: :scheduling_members }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :location_type, default: 'in_person' # in_person, phone, video
      t.text :location_details
      t.integer :duration_minutes, null: false
      t.integer :buffer_before_minutes, default: 0
      t.integer :buffer_after_minutes, default: 0
      t.integer :minimum_notice_hours, default: 0
      t.integer :maximum_days_in_future, default: 60
      t.integer :slots_per_time_slot, default: 1
      t.string :color, default: '#3b82f6'
      t.boolean :active, default: true

      # Payment settings
      t.boolean :requires_payment, default: false
      t.integer :price_cents, default: 0
      t.string :price_currency, default: 'PEN'
      t.boolean :payment_required_to_book, default: true

      # Policies
      t.boolean :allow_rescheduling, default: true
      t.integer :rescheduling_policy_hours, default: 24
      t.boolean :allow_cancellation, default: true
      t.integer :cancellation_policy_hours, default: 24

      t.jsonb :metadata, default: {}

      t.timestamps

      t.index [:member_id, :slug], unique: true
      t.index :active
    end
  end
end
