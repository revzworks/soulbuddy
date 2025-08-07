-- Profile System Migration
-- This migration creates the profile tables and RPC functions for user profile management

-- =============================================================================
-- 1. CREATE TABLES
-- =============================================================================

-- App Users table (extends auth.users)
CREATE TABLE IF NOT EXISTS app_users (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    locale text DEFAULT 'en',
    timezone text DEFAULT 'UTC',
    is_subscriber boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- App Profiles table
CREATE TABLE IF NOT EXISTS app_profiles (
    user_id uuid PRIMARY KEY REFERENCES app_users(user_id) ON DELETE CASCADE,
    name text,
    nickname text,
    date_of_birth date,
    birth_hour smallint CHECK (birth_hour >= 0 AND birth_hour <= 23),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- =============================================================================
-- 2. INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS app_users_created_at_idx ON app_users(created_at);
CREATE INDEX IF NOT EXISTS app_users_is_subscriber_idx ON app_users(is_subscriber);
CREATE INDEX IF NOT EXISTS app_profiles_user_id_idx ON app_profiles(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS app_profiles_nickname_idx ON app_profiles(nickname) WHERE nickname IS NOT NULL;

-- =============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for app_users
DROP POLICY IF EXISTS "Users can view their own data" ON app_users;
CREATE POLICY "Users can view their own data" ON app_users
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own data" ON app_users;
CREATE POLICY "Users can update their own data" ON app_users
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own data" ON app_users;
CREATE POLICY "Users can insert their own data" ON app_users
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policies for app_profiles
DROP POLICY IF EXISTS "Users can view their own profile" ON app_profiles;
CREATE POLICY "Users can view their own profile" ON app_profiles
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own profile" ON app_profiles;
CREATE POLICY "Users can update their own profile" ON app_profiles
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON app_profiles;
CREATE POLICY "Users can insert their own profile" ON app_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Service role policies (for server-side operations)
DROP POLICY IF EXISTS "Service role full access to app_users" ON app_users;
CREATE POLICY "Service role full access to app_users" ON app_users
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access to app_profiles" ON app_profiles;
CREATE POLICY "Service role full access to app_profiles" ON app_profiles
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- =============================================================================
-- 4. TRIGGERS FOR UPDATED_AT
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_app_users_updated_at ON app_users;
CREATE TRIGGER update_app_users_updated_at
    BEFORE UPDATE ON app_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_app_profiles_updated_at ON app_profiles;
CREATE TRIGGER update_app_profiles_updated_at
    BEFORE UPDATE ON app_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. RPC FUNCTIONS
-- =============================================================================

-- Function to get user profile with all data
CREATE OR REPLACE FUNCTION get_user_profile()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_data JSON;
    profile_data JSON;
    result JSON;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Get user data
    SELECT to_json(u.*) INTO user_data
    FROM app_users u
    WHERE u.user_id = auth.uid();

    -- Get profile data
    SELECT to_json(p.*) INTO profile_data
    FROM app_profiles p
    WHERE p.user_id = auth.uid();

    -- Combine results
    result := json_build_object(
        'user', user_data,
        'profile', profile_data,
        'timestamp', extract(epoch from now())
    );

    RETURN result;
END;
$$;

-- Function to upsert user profile
CREATE OR REPLACE FUNCTION upsert_profile(
    p_name text DEFAULT NULL,
    p_nickname text DEFAULT NULL,
    p_date_of_birth date DEFAULT NULL,
    p_birth_hour smallint DEFAULT NULL,
    p_locale text DEFAULT NULL,
    p_timezone text DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
    nickname_exists boolean := false;
    result JSON;
BEGIN
    -- Check if user is authenticated
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate birth_hour if provided
    IF p_birth_hour IS NOT NULL AND (p_birth_hour < 0 OR p_birth_hour > 23) THEN
        RAISE EXCEPTION 'Birth hour must be between 0 and 23';
    END IF;

    -- Check if nickname is already taken (case-insensitive)
    IF p_nickname IS NOT NULL AND trim(p_nickname) != '' THEN
        SELECT EXISTS(
            SELECT 1 FROM app_profiles 
            WHERE lower(nickname) = lower(trim(p_nickname)) 
            AND user_id != current_user_id
        ) INTO nickname_exists;
        
        IF nickname_exists THEN
            RAISE EXCEPTION 'Nickname already taken';
        END IF;
    END IF;

    -- Upsert app_users record
    INSERT INTO app_users (user_id, locale, timezone)
    VALUES (
        current_user_id,
        COALESCE(p_locale, 'en'),
        COALESCE(p_timezone, 'UTC')
    )
    ON CONFLICT (user_id) DO UPDATE SET
        locale = COALESCE(p_locale, app_users.locale),
        timezone = COALESCE(p_timezone, app_users.timezone),
        updated_at = now();

    -- Upsert app_profiles record
    INSERT INTO app_profiles (
        user_id,
        name,
        nickname,
        date_of_birth,
        birth_hour
    )
    VALUES (
        current_user_id,
        trim(p_name),
        CASE WHEN trim(p_nickname) = '' THEN NULL ELSE trim(p_nickname) END,
        p_date_of_birth,
        p_birth_hour
    )
    ON CONFLICT (user_id) DO UPDATE SET
        name = COALESCE(trim(p_name), app_profiles.name),
        nickname = CASE 
            WHEN p_nickname IS NOT NULL AND trim(p_nickname) = '' THEN NULL
            WHEN p_nickname IS NOT NULL THEN trim(p_nickname)
            ELSE app_profiles.nickname
        END,
        date_of_birth = COALESCE(p_date_of_birth, app_profiles.date_of_birth),
        birth_hour = COALESCE(p_birth_hour, app_profiles.birth_hour),
        updated_at = now();

    -- Return the updated profile
    SELECT get_user_profile() INTO result;
    
    RETURN result;
END;
$$;

-- Function to initialize user on first sign up
CREATE OR REPLACE FUNCTION initialize_user_profile()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
    auth_user_data JSON;
    extracted_name text;
    result JSON;
BEGIN
    -- Check if user is authenticated
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Check if user already exists
    IF EXISTS(SELECT 1 FROM app_users WHERE user_id = current_user_id) THEN
        -- User already exists, just return their profile
        SELECT get_user_profile() INTO result;
        RETURN result;
    END IF;

    -- Get user data from auth.users
    SELECT to_json(au.*) INTO auth_user_data
    FROM auth.users au
    WHERE au.id = current_user_id;

    -- Extract name from auth metadata if available
    extracted_name := COALESCE(
        auth_user_data->>'user_metadata'->>'full_name',
        auth_user_data->>'user_metadata'->>'name',
        split_part(auth_user_data->>'email', '@', 1)
    );

    -- Create initial user record
    INSERT INTO app_users (user_id, locale, timezone)
    VALUES (current_user_id, 'en', 'UTC');

    -- Create initial profile record with extracted name if available
    INSERT INTO app_profiles (user_id, name)
    VALUES (current_user_id, extracted_name);

    -- Return the initialized profile
    SELECT get_user_profile() INTO result;
    
    RETURN result;
END;
$$;

-- Function to delete user profile (for GDPR compliance)
CREATE OR REPLACE FUNCTION delete_user_profile()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
    result JSON;
BEGIN
    -- Check if user is authenticated
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Delete profile (cascades to related data)
    DELETE FROM app_users WHERE user_id = current_user_id;

    result := json_build_object(
        'success', true,
        'message', 'Profile deleted successfully',
        'timestamp', extract(epoch from now())
    );

    RETURN result;
END;
$$;

-- Function to check nickname availability
CREATE OR REPLACE FUNCTION check_nickname_availability(p_nickname text)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
    is_available boolean;
    result JSON;
BEGIN
    -- Check if user is authenticated
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate nickname format
    IF p_nickname IS NULL OR trim(p_nickname) = '' THEN
        RAISE EXCEPTION 'Nickname cannot be empty';
    END IF;

    -- Check availability (case-insensitive)
    SELECT NOT EXISTS(
        SELECT 1 FROM app_profiles 
        WHERE lower(nickname) = lower(trim(p_nickname)) 
        AND user_id != current_user_id
    ) INTO is_available;

    result := json_build_object(
        'available', is_available,
        'nickname', trim(p_nickname),
        'timestamp', extract(epoch from now())
    );

    RETURN result;
END;
$$;

-- =============================================================================
-- 6. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_profile(text, text, date, smallint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION initialize_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION check_nickname_availability(text) TO authenticated;

-- Grant execute permissions to anon (for initialization)
GRANT EXECUTE ON FUNCTION initialize_user_profile() TO anon;

-- Grant select/insert/update permissions to authenticated users (for RLS)
GRANT SELECT, INSERT, UPDATE ON app_users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON app_profiles TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON app_users TO service_role;
GRANT ALL ON app_profiles TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =============================================================================
-- 7. COMMENTS
-- =============================================================================

COMMENT ON TABLE app_users IS 'User account information extending auth.users';
COMMENT ON TABLE app_profiles IS 'User profile information (name, DOB, etc.)';

COMMENT ON FUNCTION get_user_profile() IS 'Returns complete user profile data';
COMMENT ON FUNCTION upsert_profile(text, text, date, smallint, text, text) IS 'Creates or updates user profile with validation';
COMMENT ON FUNCTION initialize_user_profile() IS 'Initializes user profile on first login';
COMMENT ON FUNCTION delete_user_profile() IS 'Deletes user profile and all associated data';
COMMENT ON FUNCTION check_nickname_availability(text) IS 'Checks if a nickname is available';

-- =============================================================================
-- 8. SEED DATA (Optional)
-- =============================================================================

-- Create a test user profile for development (only if in development mode)
-- This will be ignored in production
DO $$
BEGIN
    -- Only run in development environment
    IF current_setting('app.environment', true) = 'development' THEN
        -- This would create test data, but we'll skip it for now
        RAISE NOTICE 'Development environment detected - skipping seed data';
    END IF;
EXCEPTION
    WHEN others THEN
        -- Ignore errors (setting might not exist)
        NULL;
END $$; 