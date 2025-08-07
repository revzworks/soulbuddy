-- =============================================================================
-- SOULBUDDY INITIAL MIGRATION
-- This migration creates the complete database schema as described in README.md
-- =============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- =============================================================================
-- 1. CREATE TABLES
-- =============================================================================

-- App Users table (extends auth.users)
CREATE TABLE app_users (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    locale text DEFAULT 'en' NOT NULL,
    timezone text DEFAULT 'UTC' NOT NULL,
    is_subscriber boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Profiles table
CREATE TABLE app_profiles (
    user_id uuid PRIMARY KEY REFERENCES app_users(user_id) ON DELETE CASCADE,
    name text,
    nickname text,
    date_of_birth date,
    birth_hour smallint CHECK (birth_hour >= 0 AND birth_hour <= 23),
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Subscriptions table
CREATE TABLE app_subscriptions (
    user_id uuid PRIMARY KEY REFERENCES app_users(user_id) ON DELETE CASCADE,
    apple_original_transaction_id text,
    status text NOT NULL CHECK (status IN ('active', 'grace', 'lapsed', 'revoked')) DEFAULT 'lapsed',
    renews_at timestamptz,
    revoked_at timestamptz,
    last_verified_at timestamptz DEFAULT now() NOT NULL,
    reason text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Affirmation Categories table
CREATE TABLE app_affirmation_categories (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    key text NOT NULL,
    locale text NOT NULL DEFAULT 'en',
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Affirmations table
CREATE TABLE app_affirmations (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id uuid NOT NULL REFERENCES app_affirmation_categories(id) ON DELETE CASCADE,
    text text NOT NULL,
    locale text NOT NULL DEFAULT 'en',
    intensity smallint NOT NULL CHECK (intensity >= 1 AND intensity <= 3) DEFAULT 1,
    tags text[] DEFAULT '{}',
    is_active boolean DEFAULT true NOT NULL,
    last_used_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Device Tokens table
CREATE TABLE app_device_tokens (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    token text NOT NULL,
    bundle_id text NOT NULL,
    platform text DEFAULT 'ios' NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- App Notification Preferences table
CREATE TABLE app_notification_preferences (
    user_id uuid PRIMARY KEY REFERENCES app_users(user_id) ON DELETE CASCADE,
    frequency smallint NOT NULL CHECK (frequency >= 1 AND frequency <= 4) DEFAULT 2,
    quiet_start time DEFAULT '22:00' NOT NULL,
    quiet_end time DEFAULT '08:00' NOT NULL,
    allow_push boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Mood Sessions table
CREATE TABLE app_mood_sessions (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    category_id uuid NOT NULL REFERENCES app_affirmation_categories(id) ON DELETE RESTRICT,
    status text NOT NULL CHECK (status IN ('active', 'completed', 'cancelled')) DEFAULT 'active',
    started_at timestamptz DEFAULT now() NOT NULL,
    ends_at timestamptz NOT NULL,
    frequency_per_day smallint NOT NULL CHECK (frequency_per_day >= 1 AND frequency_per_day <= 4) DEFAULT 2,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Notification Schedules table
CREATE TABLE app_notification_schedules (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    mood_session_id uuid REFERENCES app_mood_sessions(id) ON DELETE CASCADE,
    scheduled_at timestamptz NOT NULL,
    payload_ref uuid REFERENCES app_affirmations(id) ON DELETE SET NULL,
    status text NOT NULL CHECK (status IN ('scheduled', 'sent', 'failed', 'skipped')) DEFAULT 'scheduled',
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- App Sent Logs table
CREATE TABLE app_sent_logs (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id uuid NOT NULL REFERENCES app_notification_schedules(id) ON DELETE CASCADE,
    sent_at timestamptz DEFAULT now() NOT NULL,
    apns_id text,
    result text NOT NULL,
    error_code text,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Analytics Events table (simple)
CREATE TABLE analytics_events (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES app_users(user_id) ON DELETE SET NULL,
    name text NOT NULL,
    props jsonb DEFAULT '{}' NOT NULL,
    ts timestamptz DEFAULT now() NOT NULL
);

-- =============================================================================
-- 2. CREATE INDEXES
-- =============================================================================

-- App Users indexes
CREATE INDEX app_users_created_at_idx ON app_users(created_at);
CREATE INDEX app_users_is_subscriber_idx ON app_users(is_subscriber);
CREATE INDEX app_users_locale_idx ON app_users(locale);

-- App Profiles indexes
CREATE INDEX app_profiles_user_id_idx ON app_profiles(user_id);
CREATE UNIQUE INDEX app_profiles_nickname_idx ON app_profiles(nickname) WHERE nickname IS NOT NULL;

-- App Subscriptions indexes
CREATE INDEX app_subscriptions_status_idx ON app_subscriptions(status);
CREATE INDEX app_subscriptions_renews_at_idx ON app_subscriptions(renews_at) WHERE renews_at IS NOT NULL;
CREATE UNIQUE INDEX app_subscriptions_apple_transaction_idx ON app_subscriptions(apple_original_transaction_id) WHERE apple_original_transaction_id IS NOT NULL;

-- App Affirmation Categories indexes
CREATE UNIQUE INDEX app_affirmation_categories_key_locale_idx ON app_affirmation_categories(key, locale);
CREATE INDEX app_affirmation_categories_active_idx ON app_affirmation_categories(is_active) WHERE is_active = true;

-- App Affirmations indexes (MUST per README)
CREATE INDEX app_affirmations_category_locale_active_idx ON app_affirmations(category_id, locale, is_active);
CREATE INDEX app_affirmations_locale_active_idx ON app_affirmations(locale, is_active) WHERE is_active = true;
CREATE INDEX app_affirmations_last_used_idx ON app_affirmations(last_used_at) WHERE last_used_at IS NOT NULL;
CREATE INDEX app_affirmations_tags_idx ON app_affirmations USING GIN(tags);

-- App Device Tokens indexes
CREATE INDEX app_device_tokens_user_id_idx ON app_device_tokens(user_id);
CREATE UNIQUE INDEX app_device_tokens_token_idx ON app_device_tokens(token);
CREATE INDEX app_device_tokens_active_idx ON app_device_tokens(is_active) WHERE is_active = true;

-- App Notification Preferences indexes
CREATE INDEX app_notification_preferences_frequency_idx ON app_notification_preferences(frequency);

-- App Mood Sessions indexes (MUST per README)
CREATE INDEX app_mood_sessions_user_status_idx ON app_mood_sessions(user_id, status);
CREATE INDEX app_mood_sessions_status_idx ON app_mood_sessions(status);
CREATE INDEX app_mood_sessions_ends_at_idx ON app_mood_sessions(ends_at);

-- CONSTRAINT: Only one active mood session per user (unique partial index)
CREATE UNIQUE INDEX app_mood_sessions_user_active_unique_idx 
ON app_mood_sessions(user_id) 
WHERE status = 'active';

-- App Notification Schedules indexes (MUST per README)
CREATE INDEX app_notification_schedules_user_scheduled_status_idx ON app_notification_schedules(user_id, scheduled_at, status);
CREATE INDEX app_notification_schedules_scheduled_status_idx ON app_notification_schedules(scheduled_at, status) WHERE status = 'scheduled';
CREATE INDEX app_notification_schedules_mood_session_idx ON app_notification_schedules(mood_session_id) WHERE mood_session_id IS NOT NULL;

-- App Sent Logs indexes (MUST per README)
CREATE INDEX app_sent_logs_schedule_id_idx ON app_sent_logs(schedule_id);
CREATE INDEX app_sent_logs_sent_at_idx ON app_sent_logs(sent_at);
CREATE INDEX app_sent_logs_result_idx ON app_sent_logs(result);

-- Analytics Events indexes
CREATE INDEX analytics_events_user_id_idx ON analytics_events(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX analytics_events_name_idx ON analytics_events(name);
CREATE INDEX analytics_events_ts_idx ON analytics_events(ts);
CREATE INDEX analytics_events_props_idx ON analytics_events USING GIN(props);

-- =============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on all app_ tables
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_affirmation_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_affirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_mood_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_notification_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_sent_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 4. RLS POLICIES
-- =============================================================================

-- App Users policies
CREATE POLICY "Users can view their own data" ON app_users
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can update their own data" ON app_users
    FOR UPDATE USING (auth.uid() = user_id);
    
CREATE POLICY "Users can insert their own data" ON app_users
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access" ON app_users
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Profiles policies
CREATE POLICY "Users can view their own profile" ON app_profiles
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can update their own profile" ON app_profiles
    FOR UPDATE USING (auth.uid() = user_id);
    
CREATE POLICY "Users can insert their own profile" ON app_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access profiles" ON app_profiles
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Subscriptions policies
CREATE POLICY "Users can view their own subscription" ON app_subscriptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role manages subscriptions" ON app_subscriptions
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Affirmation Categories policies
-- Content tables: read for all authenticated users, write only for service role
CREATE POLICY "Authenticated users can view active categories" ON app_affirmation_categories
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

CREATE POLICY "Service role manages categories" ON app_affirmation_categories
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Affirmations policies
-- Content tables: read for all authenticated users (is_active = true), write only for service role
CREATE POLICY "Authenticated users can view active affirmations" ON app_affirmations
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

CREATE POLICY "Service role manages affirmations" ON app_affirmations
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Device Tokens policies
CREATE POLICY "Users can view their own device tokens" ON app_device_tokens
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can manage their own device tokens" ON app_device_tokens
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Service role manages device tokens" ON app_device_tokens
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Notification Preferences policies
CREATE POLICY "Users can view their own preferences" ON app_notification_preferences
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can manage their own preferences" ON app_notification_preferences
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Service role manages preferences" ON app_notification_preferences
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Mood Sessions policies
CREATE POLICY "Users can view their own mood sessions" ON app_mood_sessions
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can insert their own mood sessions" ON app_mood_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);
    
CREATE POLICY "Users can update their own mood sessions" ON app_mood_sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role manages mood sessions" ON app_mood_sessions
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Notification Schedules policies
-- Users can read their own, write only via service role/Edge Functions
CREATE POLICY "Users can view their own schedules" ON app_notification_schedules
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role manages schedules" ON app_notification_schedules
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- App Sent Logs policies
-- Users can read their own via join, write only via service role
CREATE POLICY "Users can view their own sent logs" ON app_sent_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app_notification_schedules ns 
            WHERE ns.id = schedule_id AND ns.user_id = auth.uid()
        )
    );

CREATE POLICY "Service role manages sent logs" ON app_sent_logs
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Analytics Events policies
CREATE POLICY "Users can view their own events" ON analytics_events
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);
    
CREATE POLICY "Authenticated users can insert events" ON analytics_events
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Service role manages analytics" ON analytics_events
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- =============================================================================
-- 5. TRIGGERS AND FUNCTIONS
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all tables with updated_at
CREATE TRIGGER update_app_users_updated_at
    BEFORE UPDATE ON app_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_profiles_updated_at
    BEFORE UPDATE ON app_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_subscriptions_updated_at
    BEFORE UPDATE ON app_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_affirmation_categories_updated_at
    BEFORE UPDATE ON app_affirmation_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_affirmations_updated_at
    BEFORE UPDATE ON app_affirmations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_device_tokens_updated_at
    BEFORE UPDATE ON app_device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_notification_preferences_updated_at
    BEFORE UPDATE ON app_notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_mood_sessions_updated_at
    BEFORE UPDATE ON app_mood_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_notification_schedules_updated_at
    BEFORE UPDATE ON app_notification_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 6. SUBSCRIPTION MANAGEMENT FUNCTIONS
-- =============================================================================

-- Function to update subscription status and is_subscriber flag
CREATE OR REPLACE FUNCTION update_user_subscription_status(
    p_user_id uuid,
    p_status text,
    p_renews_at timestamptz DEFAULT NULL,
    p_revoked_at timestamptz DEFAULT NULL,
    p_apple_transaction_id text DEFAULT NULL,
    p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update or insert subscription record
    INSERT INTO app_subscriptions (
        user_id, status, renews_at, revoked_at, 
        apple_original_transaction_id, reason, last_verified_at
    )
    VALUES (
        p_user_id, p_status, p_renews_at, p_revoked_at,
        p_apple_transaction_id, p_reason, now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        status = EXCLUDED.status,
        renews_at = EXCLUDED.renews_at,
        revoked_at = EXCLUDED.revoked_at,
        apple_original_transaction_id = COALESCE(EXCLUDED.apple_original_transaction_id, app_subscriptions.apple_original_transaction_id),
        reason = EXCLUDED.reason,
        last_verified_at = EXCLUDED.last_verified_at,
        updated_at = now();
    
    -- Update is_subscriber flag in app_users
    UPDATE app_users 
    SET is_subscriber = (p_status = 'active' OR p_status = 'grace'),
        updated_at = now()
    WHERE user_id = p_user_id;
END;
$$;

-- Function to check and expire subscriptions
CREATE OR REPLACE FUNCTION expire_subscriptions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update expired subscriptions
    UPDATE app_subscriptions 
    SET status = 'lapsed',
        updated_at = now()
    WHERE status IN ('active', 'grace') 
    AND renews_at IS NOT NULL 
    AND renews_at < now();
    
    -- Update corresponding user flags
    UPDATE app_users 
    SET is_subscriber = false,
        updated_at = now()
    WHERE user_id IN (
        SELECT user_id FROM app_subscriptions 
        WHERE status = 'lapsed'
    ) AND is_subscriber = true;
END;
$$;

-- =============================================================================
-- 7. MOOD SESSION MANAGEMENT FUNCTIONS
-- =============================================================================

-- Function to start a new mood session (enforces one active per user)
CREATE OR REPLACE FUNCTION start_mood_session(
    p_user_id uuid,
    p_category_id uuid,
    p_frequency_per_day smallint,
    p_duration_days integer DEFAULT 7
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    session_id uuid;
    end_date timestamptz;
BEGIN
    -- Check if user is authenticated and is subscriber
    IF NOT EXISTS (
        SELECT 1 FROM app_users 
        WHERE user_id = p_user_id AND is_subscriber = true
    ) THEN
        RAISE EXCEPTION 'User must be a subscriber to start mood sessions';
    END IF;
    
    -- End any existing active sessions for this user
    UPDATE app_mood_sessions 
    SET status = 'cancelled',
        updated_at = now()
    WHERE user_id = p_user_id AND status = 'active';
    
    -- Calculate end date
    end_date := now() + (p_duration_days || ' days')::interval;
    
    -- Create new session
    INSERT INTO app_mood_sessions (
        user_id, category_id, frequency_per_day, ends_at
    )
    VALUES (p_user_id, p_category_id, p_frequency_per_day, end_date)
    RETURNING id INTO session_id;
    
    RETURN session_id;
END;
$$;

-- Function to complete or cancel mood session
CREATE OR REPLACE FUNCTION end_mood_session(
    p_session_id uuid,
    p_user_id uuid,
    p_reason text DEFAULT 'completed'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app_mood_sessions 
    SET status = CASE 
        WHEN p_reason = 'completed' THEN 'completed'
        ELSE 'cancelled'
    END,
    updated_at = now()
    WHERE id = p_session_id 
    AND user_id = p_user_id 
    AND status = 'active';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active mood session found for user';
    END IF;
END;
$$;

-- =============================================================================
-- 8. ANALYTICS FUNCTIONS
-- =============================================================================

-- Function to log analytics events (used by both profile system and app)
CREATE OR REPLACE FUNCTION log_analytics_event(
    event_name text,
    event_props jsonb DEFAULT '{}'::jsonb,
    event_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    actual_user_id uuid;
BEGIN
    -- Use provided user_id or current auth user
    actual_user_id := COALESCE(event_user_id, auth.uid());
    
    -- Insert the event
    INSERT INTO analytics_events (user_id, name, props)
    VALUES (actual_user_id, event_name, event_props);
    
    result := json_build_object(
        'success', true,
        'event', event_name,
        'user_id', actual_user_id,
        'timestamp', extract(epoch from now())
    );
    
    RETURN result;
END;
$$;

-- Function for health checks
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    result := json_build_object(
        'server_time', now(),
        'epoch', extract(epoch from now()),
        'timezone', current_setting('timezone'),
        'database', current_database(),
        'version', version()
    );
    
    RETURN result;
END;
$$;

-- Function for detailed health check
CREATE OR REPLACE FUNCTION health_check()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    user_count integer;
    profile_count integer;
    active_sessions integer;
BEGIN
    -- Get some basic metrics
    SELECT COUNT(*) INTO user_count FROM app_users;
    SELECT COUNT(*) INTO profile_count FROM app_profiles;
    SELECT COUNT(*) INTO active_sessions FROM app_mood_sessions WHERE status = 'active';
    
    result := json_build_object(
        'status', 'healthy',
        'timestamp', now(),
        'metrics', json_build_object(
            'total_users', user_count,
            'total_profiles', profile_count,
            'active_mood_sessions', active_sessions
        ),
        'database', json_build_object(
            'name', current_database(),
            'version', version(),
            'timezone', current_setting('timezone')
        )
    );
    
    RETURN result;
END;
$$;

-- =============================================================================
-- 9. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION update_user_subscription_status(uuid, text, timestamptz, timestamptz, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION expire_subscriptions() TO service_role;
GRANT EXECUTE ON FUNCTION start_mood_session(uuid, uuid, smallint, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION end_mood_session(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_analytics_event(text, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_analytics_event(text, jsonb, uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_server_time() TO authenticated;
GRANT EXECUTE ON FUNCTION get_server_time() TO anon;
GRANT EXECUTE ON FUNCTION health_check() TO authenticated;
GRANT EXECUTE ON FUNCTION health_check() TO anon;

-- Grant table permissions to authenticated users (RLS will enforce proper access)
GRANT SELECT, INSERT, UPDATE ON app_users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON app_profiles TO authenticated;
GRANT SELECT ON app_subscriptions TO authenticated;
GRANT SELECT ON app_affirmation_categories TO authenticated;
GRANT SELECT ON app_affirmations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_device_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE ON app_notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE ON app_mood_sessions TO authenticated;
GRANT SELECT ON app_notification_schedules TO authenticated;
GRANT SELECT ON app_sent_logs TO authenticated;
GRANT SELECT, INSERT ON analytics_events TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =============================================================================
-- 10. COMMENTS
-- =============================================================================

COMMENT ON TABLE app_users IS 'User account information extending auth.users';
COMMENT ON TABLE app_profiles IS 'User profile information (name, DOB, etc.)';
COMMENT ON TABLE app_subscriptions IS 'User subscription status and Apple transaction tracking';
COMMENT ON TABLE app_affirmation_categories IS 'Categories for organizing affirmations';
COMMENT ON TABLE app_affirmations IS 'Affirmation content with metadata';
COMMENT ON TABLE app_device_tokens IS 'APNs device tokens for push notifications';
COMMENT ON TABLE app_notification_preferences IS 'User notification preferences and quiet hours';
COMMENT ON TABLE app_mood_sessions IS 'Weekly mood sessions for premium users';
COMMENT ON TABLE app_notification_schedules IS 'Scheduled notifications with delivery status';
COMMENT ON TABLE app_sent_logs IS 'Logs of sent push notifications';
COMMENT ON TABLE analytics_events IS 'Simple analytics events tracking';

COMMENT ON INDEX app_mood_sessions_user_active_unique_idx IS 'Ensures only one active mood session per user';
COMMENT ON FUNCTION update_user_subscription_status(uuid, text, timestamptz, timestamptz, text, text) IS 'Updates subscription status and user is_subscriber flag';
COMMENT ON FUNCTION start_mood_session(uuid, uuid, smallint, integer) IS 'Starts a new mood session, ending any existing active session';
COMMENT ON FUNCTION log_analytics_event(text, jsonb, uuid) IS 'Logs analytics events for tracking user behavior';

-- =============================================================================
-- 11. INITIAL SEED DATA (OPTIONAL)
-- =============================================================================

-- Insert some basic affirmation categories
INSERT INTO app_affirmation_categories (key, locale, is_active) VALUES
('self_love', 'en', true),
('confidence', 'en', true),
('gratitude', 'en', true),
('motivation', 'en', true),
('calm', 'en', true),
('success', 'en', true),
('relationships', 'en', true),
('health', 'en', true);

-- Insert some sample affirmations
INSERT INTO app_affirmations (category_id, text, locale, intensity, is_active)
SELECT 
    id,
    CASE key
        WHEN 'self_love' THEN 'I am worthy of love and respect'
        WHEN 'confidence' THEN 'I believe in my abilities and trust myself'
        WHEN 'gratitude' THEN 'I am grateful for all the good in my life'
        WHEN 'motivation' THEN 'I have the power to create positive change'
        WHEN 'calm' THEN 'I am peaceful and centered in this moment'
        WHEN 'success' THEN 'I am capable of achieving my goals'
        WHEN 'relationships' THEN 'I attract positive and loving relationships'
        WHEN 'health' THEN 'My body is strong and healthy'
    END,
    'en',
    1,
    true
FROM app_affirmation_categories 
WHERE locale = 'en';

-- Log the completion of migration
SELECT log_analytics_event('database_migration_completed', '{"migration": "0001_init", "tables_created": 11}'::jsonb); 