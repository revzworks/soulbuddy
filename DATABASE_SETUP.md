# SoulBuddy Database Setup

This document explains how to set up the SoulBuddy database schema using Supabase.

## Overview

The database schema implements the complete data model described in the README.md, including:

- **11 core tables** with proper relationships and constraints
- **Comprehensive RLS policies** for security
- **Performance indexes** for all critical queries
- **Utility functions** for common operations
- **Unique constraints** to enforce business rules

## Quick Start

### 1. Apply the Migration

```bash
# Reset and apply all migrations
supabase db reset

# Or apply specific migration
supabase migration up
```

### 2. Run Tests

```bash
# Run the database tests
supabase db test
```

### 3. Verify Setup

```sql
-- Check that all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name LIKE 'app_%';

-- Verify RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename LIKE 'app_%';
```

## Schema Overview

### Core Tables

#### User Management
- **`app_users`** - Extends auth.users with app-specific data
- **`app_profiles`** - User profile information (name, DOB, etc.)
- **`app_subscriptions`** - Subscription status and Apple transactions

#### Content Management  
- **`app_affirmation_categories`** - Categories for organizing affirmations
- **`app_affirmations`** - Affirmation content with metadata

#### Notifications & Sessions
- **`app_device_tokens`** - APNs tokens for push notifications
- **`app_notification_preferences`** - User notification settings
- **`app_mood_sessions`** - Weekly mood sessions for premium users
- **`app_notification_schedules`** - Scheduled notifications
- **`app_sent_logs`** - Delivery logs for sent notifications

#### Analytics
- **`analytics_events`** - Simple event tracking

### Key Constraints

#### Unique Active Mood Session
```sql
-- Only one active mood session per user
CREATE UNIQUE INDEX app_mood_sessions_user_active_unique_idx 
ON app_mood_sessions(user_id) 
WHERE status = 'active';
```

#### Nickname Uniqueness
```sql
-- Case-insensitive unique nicknames
CREATE UNIQUE INDEX app_profiles_nickname_idx 
ON app_profiles(nickname) 
WHERE nickname IS NOT NULL;
```

### RLS Policies

All tables implement Row Level Security with these patterns:

#### User Data Tables
- **Users can view/edit their own data**: `auth.uid() = user_id`
- **Service role has full access**: `auth.jwt() ->> 'role' = 'service_role'`

#### Content Tables (Categories & Affirmations)
- **Authenticated users can read active content**: `auth.role() = 'authenticated' AND is_active = true`
- **Only service role can write**: For content management

#### Logs & Schedules
- **Users can read their own data**: Via joins or direct user_id checks
- **Only service role can write**: For system operations

### Critical Indexes

The following indexes are required for performance (as per README):

```sql
-- Affirmations (MUST)
app_affirmations(category_id, locale, is_active)

-- Notification Schedules (MUST)  
app_notification_schedules(user_id, scheduled_at, status)

-- Sent Logs (MUST)
app_sent_logs(schedule_id)

-- Mood Sessions (MUST)
app_mood_sessions(user_id, status)
```

## Utility Functions

### Profile Management
```sql
-- Get complete user profile
SELECT get_user_profile();

-- Update user profile (from 002_profile_system.sql)
SELECT upsert_profile('John Doe', 'johndoe', '1990-01-01', 12);
```

### Subscription Management
```sql
-- Update subscription status
SELECT update_user_subscription_status(
    user_id, 'active', now() + interval '1 month', 
    null, 'apple_transaction_123', 'purchased'
);

-- Expire old subscriptions (run via cron)
SELECT expire_subscriptions();
```

### Mood Sessions
```sql
-- Start new mood session (enforces one active per user)
SELECT start_mood_session(user_id, category_id, 3, 7);

-- End mood session
SELECT end_mood_session(session_id, user_id, 'completed');
```

### Analytics & Health
```sql
-- Log analytics event
SELECT log_analytics_event('user_action', '{"page": "home"}'::jsonb);

-- Health check
SELECT health_check();

-- Server time
SELECT get_server_time();
```

## Security Model

### Authentication Flow
1. User signs up via Supabase Auth (Apple/Google/Email)
2. `app_users` record created automatically via trigger or RPC
3. User profile created via `initialize_user_profile()` or ProfileSetupView
4. All subsequent operations use `auth.uid()` for access control

### Data Access Patterns
- **User data**: Direct access via RLS policies  
- **Content**: Read-only for authenticated users
- **System operations**: Service role via Edge Functions
- **Analytics**: User can read own events, insert any

### Subscription Enforcement
- Mood sessions require `is_subscriber = true`
- Subscription status synced via App Store Server Notifications
- Service role updates subscription status via webhooks

## Testing

The migration includes comprehensive tests in `.supabase/tests/database_test.sql`:

1. **Table existence** - All 11 tables created
2. **Constraint enforcement** - Unique active sessions, birth_hour validation
3. **RLS policies** - Proper policies exist and RLS enabled
4. **Index verification** - Critical indexes present
5. **Function testing** - All utility functions work
6. **Seed data** - Basic categories and affirmations inserted

### Running Tests

```bash
# Run all tests
supabase db test

# Run specific test file
psql -f .supabase/tests/database_test.sql
```

## Troubleshooting

### Common Issues

#### Migration Fails
```bash
# Check for syntax errors
supabase db lint

# Reset and try again
supabase db reset
```

#### RLS Blocking Queries
```sql
-- Temporarily disable RLS for debugging (dev only)
ALTER TABLE app_users DISABLE ROW LEVEL SECURITY;

-- Re-enable after fixing
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
```

#### Performance Issues
```sql
-- Check if indexes are being used
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM app_affirmations 
WHERE category_id = 'some-uuid' AND locale = 'en' AND is_active = true;
```

### Debugging RLS

```sql
-- Check current user context
SELECT 
    auth.uid() as user_id,
    auth.role() as role,
    auth.jwt() ->> 'role' as jwt_role;

-- Test policy manually
SELECT * FROM app_profiles WHERE auth.uid() = user_id;
```

## Production Considerations

### Monitoring
- Set up alerts for failed migrations
- Monitor query performance via pg_stat_statements
- Track RLS policy violations

### Backup Strategy
- Supabase handles automated backups
- Consider point-in-time recovery for critical operations
- Test restore procedures regularly

### Scaling
- Monitor index usage and add as needed
- Consider partitioning for analytics_events table
- Use read replicas for reporting queries

### Security
- Regularly audit RLS policies
- Monitor for privilege escalation attempts
- Keep service role credentials secure

## Migration History

- **0001_init.sql** - Initial schema with all tables, indexes, RLS, and seed data
- **002_profile_system.sql** - Enhanced profile management with RPC functions

Each migration is idempotent and can be safely re-run. 