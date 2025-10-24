class CreateSchedulingSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_schedules do |t|
      t.references :member, null: false, foreign_key: { to_table: :scheduling_members }
      t.string :name, null: false
      t.string :timezone, null: false
      t.boolean :is_default, default: false

      t.timestamps

      t.index [:member_id, :is_default]
    end

    create_table :scheduling_availabilities do |t|
      t.references :schedule, null: false, foreign_key: { to_table: :scheduling_schedules }
      t.integer :day_of_week, null: false # 0-6 (Sunday-Saturday)
      t.time :start_time, null: false
      t.time :end_time, null: false

      t.timestamps

      t.index [:schedule_id, :day_of_week]
    end

    create_table :scheduling_date_overrides do |t|
      t.references :member, null: false, foreign_key: { to_table: :scheduling_members }
      t.date :date, null: false
      t.time :start_time
      t.time :end_time
      t.boolean :unavailable, default: false
      t.text :reason

      t.timestamps

      t.index [:member_id, :date]
    end
  end
end
