-- Analytics Functions for SoulBuddy
-- Run this SQL in your Supabase SQL Editor

-- Create analytics event logging function
CREATE OR REPLACE FUNCTION log_analytics_event(
    event_name TEXT,
    event_props JSONB DEFAULT '{}'::JSONB,
    event_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Insert analytics event
    INSERT INTO analytics_events (
        id,
        user_id,
        name,
        props,
        ts
    ) VALUES (
        gen_random_uuid(),
        COALESCE(event_user_id, auth.uid()),
        event_name,
        event_props,
        NOW()
    );
    
    -- Return success response
    result := json_build_object(
        'success', true,
        'event', event_name,
        'timestamp', NOW()
    );
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Return error response
        result := json_build_object(
            'success', false,
            'error', SQLERRM,
            'event', event_name
        );
        RETURN result;
END;
$$;

-- Create server time function for connection testing
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    result := json_build_object(
        'server_time', NOW(),
        'timezone', current_setting('TIMEZONE'),
        'version', version(),
        'database', current_database()
    );
    
    RETURN result;
END;
$$;

-- Create health check function
CREATE OR REPLACE FUNCTION health_check()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    db_size BIGINT;
    active_connections INT;
BEGIN
    -- Get database metrics
    SELECT pg_database_size(current_database()) INTO db_size;
    SELECT count(*) FROM pg_stat_activity WHERE state = 'active' INTO active_connections;
    
    result := json_build_object(
        'status', 'healthy',
        'timestamp', NOW(),
        'database', json_build_object(
            'name', current_database(),
            'size_bytes', db_size,
            'active_connections', active_connections
        ),
        'auth', json_build_object(
            'user_id', auth.uid(),
            'role', auth.role()
        )
    );
    
    RETURN result;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION log_analytics_event(TEXT, JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION log_analytics_event(TEXT, JSONB, UUID) TO anon;

GRANT EXECUTE ON FUNCTION get_server_time() TO authenticated;
GRANT EXECUTE ON FUNCTION get_server_time() TO anon;

GRANT EXECUTE ON FUNCTION health_check() TO authenticated;
GRANT EXECUTE ON FUNCTION health_check() TO anon;

-- Create indexes for analytics_events if they don't exist
CREATE INDEX IF NOT EXISTS idx_analytics_events_name ON analytics_events(name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_ts ON analytics_events(ts);

-- Create a view for analytics insights (optional)
CREATE OR REPLACE VIEW analytics_insights AS
SELECT 
    name,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    DATE_TRUNC('day', ts) as event_date,
    MIN(ts) as first_occurrence,
    MAX(ts) as last_occurrence
FROM analytics_events 
WHERE ts >= NOW() - INTERVAL '30 days'
GROUP BY name, DATE_TRUNC('day', ts)
ORDER BY event_date DESC, event_count DESC;

-- Grant view access
GRANT SELECT ON analytics_insights TO authenticated; 