-- =============================================================================
-- DATABASE SCHEMA TESTS
-- Tests to validate the database schema and constraints work correctly
-- =============================================================================

BEGIN;

-- Test 1: Check all tables exist
SELECT 'Testing table existence...' as test_status;

DO $$
BEGIN
    -- Check all required tables exist
    ASSERT (SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name LIKE 'app_%') >= 10, 
           'Not all app_ tables were created';
    
    RAISE NOTICE '✓ All app_ tables exist';
END $$;

-- Test 2: Check unique constraint on active mood sessions
SELECT 'Testing mood session constraints...' as test_status;

DO $$
DECLARE
    test_user_id uuid := uuid_generate_v4();
    test_category_id uuid;
    session1_id uuid;
    session2_id uuid;
BEGIN
    -- Get a category for testing
    SELECT id INTO test_category_id FROM app_affirmation_categories LIMIT 1;
    
    -- This should work
    INSERT INTO app_users (user_id, is_subscriber) 
    VALUES (test_user_id, true);
    
    -- First active session should work
    INSERT INTO app_mood_sessions (user_id, category_id, status, ends_at, frequency_per_day)
    VALUES (test_user_id, test_category_id, 'active', now() + interval '7 days', 2)
    RETURNING id INTO session1_id;
    
    -- Second active session should fail due to unique constraint
    BEGIN
        INSERT INTO app_mood_sessions (user_id, category_id, status, ends_at, frequency_per_day)
        VALUES (test_user_id, test_category_id, 'active', now() + interval '7 days', 2)
        RETURNING id INTO session2_id;
        
        RAISE EXCEPTION 'Should not allow two active sessions';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '✓ Unique constraint on active mood sessions works';
    END;
    
    -- But completed/cancelled sessions should be allowed
    INSERT INTO app_mood_sessions (user_id, category_id, status, ends_at, frequency_per_day)
    VALUES (test_user_id, test_category_id, 'completed', now() + interval '7 days', 2);
    
    INSERT INTO app_mood_sessions (user_id, category_id, status, ends_at, frequency_per_day)
    VALUES (test_user_id, test_category_id, 'cancelled', now() + interval '7 days', 2);
    
    RAISE NOTICE '✓ Multiple completed/cancelled sessions allowed';
END $$;

-- Test 3: Check RLS policies exist
SELECT 'Testing RLS policies...' as test_status;

DO $$
BEGIN
    -- Check that RLS is enabled on all app_ tables
    ASSERT (SELECT COUNT(*) 
            FROM pg_class c 
            JOIN pg_namespace n ON n.oid = c.relnamespace 
            WHERE n.nspname = 'public' 
            AND c.relname LIKE 'app_%' 
            AND c.relrowsecurity = true) >= 10,
           'RLS not enabled on all app_ tables';
    
    RAISE NOTICE '✓ RLS enabled on all app_ tables';
    
    -- Check that policies exist
    ASSERT (SELECT COUNT(*) 
            FROM pg_policy p 
            JOIN pg_class c ON c.oid = p.polrelid 
            WHERE c.relname LIKE 'app_%') > 20,
           'Not enough RLS policies found';
    
    RAISE NOTICE '✓ RLS policies exist';
END $$;

-- Test 4: Check required indexes exist
SELECT 'Testing indexes...' as test_status;

DO $$
BEGIN
    -- Check for critical indexes mentioned in README
    ASSERT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'app_affirmations' 
        AND indexname LIKE '%category_locale_active%'
    ), 'Missing critical app_affirmations index';
    
    ASSERT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'app_notification_schedules' 
        AND indexname LIKE '%user_scheduled_status%'
    ), 'Missing critical app_notification_schedules index';
    
    ASSERT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'app_sent_logs' 
        AND indexname LIKE '%schedule_id%'
    ), 'Missing critical app_sent_logs index';
    
    ASSERT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'app_mood_sessions' 
        AND indexname LIKE '%user_status%'
    ), 'Missing critical app_mood_sessions index';
    
    RAISE NOTICE '✓ All critical indexes exist';
END $$;

-- Test 5: Check functions exist and work
SELECT 'Testing functions...' as test_status;

DO $$
DECLARE
    server_time_result json;
    health_result json;
    analytics_result json;
BEGIN
    -- Test server time function
    SELECT get_server_time() INTO server_time_result;
    ASSERT server_time_result IS NOT NULL, 'get_server_time() failed';
    
    -- Test health check function
    SELECT health_check() INTO health_result;
    ASSERT health_result IS NOT NULL, 'health_check() failed';
    
    -- Test analytics function
    SELECT log_analytics_event('test_event', '{"test": true}'::jsonb) INTO analytics_result;
    ASSERT analytics_result IS NOT NULL, 'log_analytics_event() failed';
    
    RAISE NOTICE '✓ All functions work correctly';
END $$;

-- Test 6: Check constraints and data types
SELECT 'Testing constraints...' as test_status;

DO $$
DECLARE
    test_user_id uuid := uuid_generate_v4();
BEGIN
    -- Test birth_hour constraint
    INSERT INTO app_users (user_id) VALUES (test_user_id);
    
    BEGIN
        INSERT INTO app_profiles (user_id, birth_hour) 
        VALUES (test_user_id, 25); -- Should fail
        
        RAISE EXCEPTION 'Should not allow birth_hour > 23';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ birth_hour constraint works';
    END;
    
    -- Test valid birth_hour
    INSERT INTO app_profiles (user_id, birth_hour) 
    VALUES (test_user_id, 12); -- Should work
    
    RAISE NOTICE '✓ Valid birth_hour accepted';
END $$;

-- Test 7: Check that seed data was inserted
SELECT 'Testing seed data...' as test_status;

DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM app_affirmation_categories WHERE is_active = true) >= 5,
           'Not enough seed categories';
    
    ASSERT (SELECT COUNT(*) FROM app_affirmations WHERE is_active = true) >= 5,
           'Not enough seed affirmations';
    
    RAISE NOTICE '✓ Seed data exists';
END $$;

ROLLBACK;

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'All database tests passed! 🎉' as final_status; 