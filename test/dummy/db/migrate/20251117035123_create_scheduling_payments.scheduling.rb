# This migration comes from scheduling (originally 20241024000006)
class CreateSchedulingPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_payments do |t|
      t.references :booking, null: false, foreign_key: { to_table: :scheduling_bookings }
      t.integer :amount_cents, null: false
      t.string :amount_currency, null: false
      t.string :status, default: 'pending' # pending, completed, failed, refunded
      t.string :payment_method # stripe, culqi, cash, transfer
      t.string :payment_provider # stripe, culqi
      t.string :external_transaction_id
      t.datetime :paid_at
      t.text :failure_reason
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index :status
      t.index :external_transaction_id
      t.index [:booking_id, :status]
    end
  end
end
