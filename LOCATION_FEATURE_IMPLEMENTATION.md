# Location Feature Implementation

## Summary

This document describes the implementation of proper location handling for in-person meetings in the scheduling engine.

## Changes Made

### 1. Database Migration

**File**: `db/migrate/20250116_add_location_details_to_event_types.rb`

Added the following fields to `scheduling_event_types` table:
- `location_address` (string) - Primary street address
- `location_address_line_2` (string) - Apartment, suite, etc.
- `location_city` (string) - City name
- `location_state` (string) - State/Province
- `location_postal_code` (string) - ZIP/Postal code
- `location_country` (string) - Country name
- `location_latitude` (decimal 10,6) - GPS latitude coordinate
- `location_longitude` (decimal 10,6) - GPS longitude coordinate
- `location_instructions` (text) - Additional instructions (parking, entrance, etc.)

### 2. Model Updates

**File**: `app/models/scheduling/event_type.rb`

**Validations Added:**
- `location_address` is required when `location_type` is `'in_person'`
- `location_latitude` and `location_longitude` must be numeric if present

**New Methods:**
- `full_address` - Returns formatted full address string
- `google_maps_url` - Generates Google Maps URL from coordinates

### 3. View Updates

**File**: `app/views/scheduling/public_bookings/show.html.erb`

**Removed:**
- Confirmation code display section (UUID was not user-friendly)

**Enhanced Location Display:**
- Shows full address for in-person meetings
- Displays location instructions if provided
- Includes "View on Google Maps" link when coordinates are available
- Different icons for each location type (in_person, video, phone)
- Proper fallback for video call URLs
- Clean display for phone appointments

### 4. Translation Updates

**Files**: 
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/locales/fr.yml`
- `config/locales/pt.yml`

**Removed:**
- `confirmation_code` translation key

**Added:**
- `view_map` - "View on Google Maps" (and translations)
- `phone` - "Phone Call" (and translations)

## Usage

### For Admins (Setting up Event Types)

When creating or editing an event type with `location_type: 'in_person'`:

1. **Required**: Enter the street address in `location_address`
2. **Optional but recommended**: 
   - Add `location_city`, `location_state`, `location_postal_code`, `location_country`
   - Add GPS coordinates (`location_latitude`, `location_longitude`) for Google Maps integration
   - Add `location_instructions` for parking, entrance details, etc.

Example:
```ruby
event_type = EventType.create!(
  title: "In-Person Consultation",
  location_type: "in_person",
  location_address: "123 Main Street",
  location_address_line_2: "Suite 200",
  location_city: "San Francisco",
  location_state: "CA",
  location_postal_code: "94102",
  location_country: "USA",
  location_latitude: 37.7749,
  location_longitude: -122.4194,
  location_instructions: "Free parking available in the building garage. Use the north entrance."
)
```

### For Clients (Viewing Bookings)

When viewing a confirmed booking:
- **In-Person**: Full address is displayed with optional Google Maps link
- **Video Call**: Shows "Video Call" with meeting URL if available
- **Phone**: Shows "Phone Call"

## Migration Instructions

To apply these changes to an existing installation:

1. Run the migration:
   ```bash
   rails db:migrate
   ```

2. Update existing in-person event types with address information:
   ```ruby
   # In Rails console or seeds
   EventType.where(location_type: 'in_person').each do |event_type|
     event_type.update!(
       location_address: "Your address here",
       location_city: "City",
       # ... other fields
     )
   end
   ```

## Benefits

1. **Better User Experience**: Clients see the exact address instead of just "In Person"
2. **Google Maps Integration**: One-click navigation to the appointment location
3. **Cleaner UI**: Removed technical UUID that wasn't useful to clients
4. **Flexible**: Supports various address formats and optional fields
5. **International**: Works with any country's address format

## Future Enhancements

Potential improvements for the admin interface:
- Address autocomplete using Google Places API
- Automatic coordinate lookup from address
- Map preview when entering coordinates
- Validation of coordinates (ensure they're within reasonable ranges)
- Support for multiple locations per member/organization
