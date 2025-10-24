class CreateSchedulingOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, null: false, default: 'America/Lima'
      t.string :default_currency, default: 'PEN'
      t.string :default_locale, default: 'es'
      t.text :logo_url
      t.text :description
      t.boolean :active, default: true
      t.jsonb :settings, default: {}

      t.timestamps

      t.index :slug, unique: true
      t.index :active
    end

    create_table :scheduling_locations do |t|
      t.references :organization, null: false, foreign_key: { to_table: :scheduling_organizations }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :address
      t.string :city
      t.string :state
      t.string :country
      t.string :postal_code
      t.string :phone
      t.string :email
      t.string :timezone, null: false, default: 'America/Lima'
      t.boolean :active, default: true
      t.jsonb :settings, default: {}

      t.timestamps

      t.index [:organization_id, :slug], unique: true
      t.index :active
    end

    create_table :scheduling_teams do |t|
      t.references :location, null: false, foreign_key: { to_table: :scheduling_locations }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :color, default: '#3b82f6'
      t.boolean :active, default: true
      t.jsonb :settings, default: {}

      t.timestamps

      t.index [:location_id, :slug], unique: true
      t.index :active
    end

    create_table :scheduling_members do |t|
      t.references :team, null: false, foreign_key: { to_table: :scheduling_teams }
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'member' # admin, manager, member
      # Note: title and bio should be in User model (host app responsibility)
      t.text :avatar_url
      t.string :booking_slug, null: false
      t.boolean :active, default: true
      t.boolean :accepts_bookings, default: true
      t.jsonb :settings, default: {}

      t.timestamps

      t.index :booking_slug, unique: true
      t.index [:team_id, :user_id], unique: true
      t.index :active
    end

    create_table :scheduling_clients do |t|
      t.references :organization, null: false, foreign_key: { to_table: :scheduling_organizations }
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone
      t.string :timezone, default: 'America/Lima'
      t.string :locale, default: 'es'
      t.text :notes
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index [:organization_id, :email], unique: true
      t.index :email
    end
  end
end
