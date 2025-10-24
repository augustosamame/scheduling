# Refactoring Summary: Proper Data Ownership

## What Changed

We refactored the engine to follow DRY principles by moving `title` and `bio` from `Scheduling::Member` to the host app's `User` model.

## Before (❌ Violating DRY)

```ruby
User                              Scheduling::Member
├── first_name                    ├── first_name (DUPLICATE!)
├── last_name                     ├── last_name (DUPLICATE!)
├── email                         ├── email (DUPLICATE!)
                                  ├── title (DUPLICATE!)
                                  ├── bio (DUPLICATE!)
                                  ├── role
                                  └── booking_slug (derived from name - sync issue!)
```

**Problems:**
- Data duplication
- Sync issues if user name changes
- Unclear ownership

## After (✅ DRY Principles)

```ruby
User (Host App)                   Scheduling::Member (Engine)
├── first_name                    ├── role (scheduling-specific)
├── last_name                     ├── avatar_url (scheduling-specific)
├── email                         ├── booking_slug (scheduling-specific)
├── title                         ├── active (scheduling-specific)
├── bio                           ├── accepts_bookings (scheduling-specific)
                                  └── settings (scheduling-specific)
                                       ↑
                                  Delegates to User:
                                  - first_name
                                  - last_name
                                  - email
                                  - title
                                  - bio
```

## What Was Modified

### 1. Database Migrations

**Created:**
- `20251024211640_remove_title_and_bio_from_scheduling_members.rb`
- `20251024211658_add_title_and_bio_to_users.rb`

**Updated:**
- `db/migrate/20241024000001_create_scheduling_organizations.rb` - Removed title/bio from initial schema

### 2. Model Changes

**`app/models/scheduling/member.rb`:**
```ruby
# Added delegation
delegate :first_name, :last_name, :email, :title, :bio, to: :user, prefix: false, allow_nil: true
```

### 3. Seed Data Updated

**`test/dummy/db/seeds.rb`:**
- Moved `title` and `bio` to User creation
- Removed from Member creation

## Testing the Changes

```ruby
member = Scheduling::Member.first

# Delegated from User (no duplication!)
member.first_name  # => "Dr. Maria"
member.last_name   # => "Rodriguez"
member.title       # => "Cardiologist" (from user.title)
member.bio         # => "15 years..." (from user.bio)
member.full_name   # => "Dr. Maria Rodriguez" (computed)

# Stored in Member (scheduling-specific)
member.role        # => "admin"
member.booking_slug # => "dr-maria-rodriguez"
member.accepts_bookings # => true

# If user updates their info (automatic sync via delegation!)
member.user.update(title: "Senior Cardiologist")
member.reload
member.title # => "Senior Cardiologist" (no manual sync needed!)
```

## Benefits

✅ **Single Source of Truth**: User identity data lives in one place
✅ **Automatic Sync**: Changes to user propagate automatically via delegation
✅ **Clear Ownership**: Engine stores only scheduling-specific data
✅ **DRY Compliance**: No data duplication
✅ **Flexible**: Host app controls what a "user" is

## Host App Requirements

When using this engine, your User model should have:

```ruby
class User < ApplicationRecord
  # Required for engine
  has_many :scheduling_members, class_name: 'Scheduling::Member'

  # Required fields (must exist)
  # - first_name :string
  # - last_name :string
  # - email :string

  # Recommended fields (for public booking pages)
  # - title :string (e.g., "Cardiologist")
  # - bio :text (professional biography)
end
```

## Migration Path for Existing Apps

If you're upgrading an existing installation:

1. Add `title` and `bio` to your User model
2. Copy data from members to users:
   ```ruby
   Scheduling::Member.find_each do |member|
     member.user.update(
       title: member.read_attribute(:title),
       bio: member.read_attribute(:bio)
     )
   end
   ```
3. Run: `rails scheduling:install:migrations`
4. Run: `rails db:migrate`
5. Profit! 🎉

## Questions?

See `DATA_OWNERSHIP.md` for detailed architectural decisions.
