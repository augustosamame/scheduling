# Data Ownership Guidelines

## ✅ Final Architecture (Refactored for DRY Principles)

**Key Principle**: The engine stores only scheduling-specific data. User identity and professional info lives in the host app's User model.

## Current Architecture (After Refactoring)

### ✅ What SHOULD Be in Member

```ruby
Scheduling::Member
├── role                    # Scheduling-specific: admin/manager/member of THIS team
├── avatar_url              # Profile picture for booking pages (optional)
├── booking_slug            # Unique URL slug for public booking page
├── active                  # Whether member is active in scheduling system
├── accepts_bookings        # Whether member is currently accepting appointments
└── settings                # Scheduling-specific preferences (JSONB)
```

**Why these belong in Member:**
- **Scheduling domain-specific**: These attributes only matter in the context of scheduling
- **Team-specific**: role, active, and accepts_bookings can differ per team
- **Public booking page**: avatar_url and booking_slug are for the public-facing scheduling page
- **Business logic**: accepts_bookings controls scheduling availability, not user status

### ❌ What SHOULD NOT Be in Member (Delegate from User Instead)

```ruby
# ❌ BAD - Duplicating User data
Scheduling::Member
├── first_name   # Delegate to user.first_name
├── last_name    # Delegate to user.last_name
├── email        # Delegate to user.email
├── title        # Delegate to user.title
└── bio          # Delegate to user.bio

# ✅ GOOD - Use delegation
class Member < ApplicationRecord
  delegate :first_name, :last_name, :email, :title, :bio, to: :user

  def full_name
    "#{first_name} #{last_name}"
  end
end

# Host app's User model should have:
class User < ApplicationRecord
  # Identity
  has_many :scheduling_members, class_name: 'Scheduling::Member'

  # Professional info (lives here, not in Member!)
  # - first_name
  # - last_name
  # - email
  # - title (e.g., "Cardiologist")
  # - bio (professional biography)
end
```

## ✅ Decision Made: title and bio Live in User

We've chosen to keep `title` and `bio` in the User model because:

1. **Most common use case**: Users have ONE professional identity
2. **DRY principle**: Don't duplicate professional info
3. **Simplicity**: Easier to maintain user profile in one place
4. **Host app control**: The host app defines what a "user" is

### If You Need Multi-Context (Rare)

If you truly need different titles/bios per team, you can:

```ruby
# Option 1: Use settings JSONB field
member.settings = {
  display_title: "Senior Cardiologist",
  display_bio: "Specializing in preventive care"
}

# Option 2: Add back to Member (but you probably don't need this)
```

## What About booking_slug?

The `booking_slug` is **derived** from user data but should stay in Member because:

1. **It's scheduling-specific**: Used only for public booking URLs
2. **It's stable**: Once set, it shouldn't change even if user's name changes
3. **It's unique per scheduling context**: Different from user.id or user.slug
4. **SEO-friendly**: `/book/dr-maria-rodriguez` is better than `/book/123`

### Keeping booking_slug in Sync

```ruby
# Current approach: Generate once, keep forever
before_validation :generate_booking_slug, on: :create

# Alternative: Sync when user changes name (NOT recommended - breaks URLs)
after_save :update_booking_slug_if_name_changed

def update_booking_slug_if_name_changed
  if user.previous_changes.key?('first_name') || user.previous_changes.key?('last_name')
    generate_booking_slug
    save(validate: false) # Skip validations to avoid loops
  end
end
```

⚠️ **Recommendation**: Keep booking_slug permanent to avoid breaking bookmark URLs

## Role Ownership

### ❓ Should `role` be in Member or User?

**In Member (Current approach - Recommended):**
```ruby
# A user can be admin of Cardiology team but member of Surgery team
user.scheduling_members.find_by(team: cardiology).admin?  # => true
user.scheduling_members.find_by(team: surgery).admin?     # => false
```

**In User (Alternative - Not recommended):**
```ruby
# User is admin of everything or nothing
user.admin?  # => too broad, not context-specific
```

**Best practice**: Keep `role` in Member for fine-grained permissions.

## Summary

### Keep in Scheduling::Member
- ✅ `role` - Scheduling team role
- ✅ `title` - Professional title (if context-specific)
- ✅ `bio` - Professional bio (if context-specific)
- ✅ `avatar_url` - Profile picture for bookings
- ✅ `booking_slug` - Unique URL for bookings
- ✅ `active` - Scheduling system status
- ✅ `accepts_bookings` - Availability toggle
- ✅ `settings` - Scheduling preferences

### Delegate from User
- ✅ `first_name` - Via delegation
- ✅ `last_name` - Via delegation
- ✅ `email` - Via delegation
- ✅ Any other user identity attributes

### Consider Based on Context
- ❓ `title` - Keep if users have different titles per team
- ❓ `bio` - Keep if users have different bios per team

## Testing the Refactored Approach

```ruby
member = Scheduling::Member.first

# These now come from User via delegation
member.first_name   # => "Maria" (from user)
member.last_name    # => "Rodriguez" (from user)
member.email        # => "maria@clinic.com" (from user)
member.full_name    # => "Maria Rodriguez" (computed)

# These are stored in Member
member.role         # => "admin" (scheduling-specific)
member.title        # => "Cardiologist" (professional context)
member.bio          # => "15 years experience..." (public booking page)
member.booking_slug # => "dr-maria-rodriguez" (URL-friendly)

# If user's name changes in the host app
member.user.update(first_name: "Dr. Maria Elena")
member.reload
member.first_name   # => "Dr. Maria Elena" (automatically synced via delegation!)
member.booking_slug # => "dr-maria-rodriguez" (stays the same - stable URLs)
```

## Migration Path

If you want to remove `title` and `bio` from Member:

1. Add them to User model in host app
2. Migrate data: `Member.all.each { |m| m.user.update(title: m.title, bio: m.bio) }`
3. Remove columns from Member
4. Update Member model to delegate these attributes
5. Update migrations for new installations

For now, keeping them in Member offers maximum flexibility! 🎯
