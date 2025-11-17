# This migration comes from scheduling (originally 20241024000005)
class CreateSchedulingBookingQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_booking_questions do |t|
      t.references :event_type, null: false, foreign_key: { to_table: :scheduling_event_types }
      t.string :label, null: false
      t.string :question_type, null: false # text, textarea, email, phone, url, select, radio, checkbox, number, date
      t.text :options # JSON array for select/radio/checkbox
      t.boolean :required, default: false
      t.integer :position, default: 0
      t.text :placeholder
      t.text :help_text

      t.timestamps

      t.index [:event_type_id, :position]
    end

    create_table :scheduling_booking_answers do |t|
      t.references :booking, null: false, foreign_key: { to_table: :scheduling_bookings }
      t.references :booking_question, null: false, foreign_key: { to_table: :scheduling_booking_questions }
      t.text :answer

      t.timestamps

      t.index [:booking_id, :booking_question_id], name: 'index_booking_answers_on_booking_and_question'
    end
  end
end
