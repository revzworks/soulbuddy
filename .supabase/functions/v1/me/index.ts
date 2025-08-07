// =============================================================================
// ME ENDPOINT - GET /functions/v1/me
// Returns complete user profile, preferences, and subscription information
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  createErrorResponse,
  createSuccessResponse,
  authenticateUser,
  validateMethod,
  logAnalyticsEvent,
  type UserMeResponse,
  type UserProfile,
  type NotificationPreferences
} from "../../_shared/types.ts"

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate HTTP method
    validateMethod(req, ['GET'])

    // Authenticate user
    const { user, supabase } = await authenticateUser(req)

    console.log(`📋 Fetching complete profile for user: ${user.id}`)

    // Get user profile using RPC function
    const { data: profileData, error: profileError } = await supabase.rpc('get_user_profile')

    if (profileError) {
      console.error('Profile fetch error:', profileError)
      return createErrorResponse('Failed to fetch user profile', 500, profileError)
    }

    // Get notification preferences
    const { data: preferencesData, error: preferencesError } = await supabase
      .from('app_notification_preferences')
      .select('*')
      .eq('user_id', user.id)
      .single()

    // Get subscription status
    const { data: subscriptionData, error: subscriptionError } = await supabase
      .from('app_subscriptions')
      .select('status, renews_at, last_verified_at')
      .eq('user_id', user.id)
      .single()

    // Get user info from app_users table
    const { data: userData, error: userError } = await supabase
      .from('app_users')
      .select('locale, timezone, is_subscriber, created_at')
      .eq('user_id', user.id)
      .single()

    if (userError) {
      console.error('User data fetch error:', userError)
      return createErrorResponse('Failed to fetch user data', 500, userError)
    }

    // Build response object
    const response: UserMeResponse = {
      user: {
        id: user.id,
        email: user.email,
        created_at: user.created_at,
        last_sign_in_at: user.last_sign_in_at
      },
      profile: undefined,
      preferences: undefined,
      subscription: undefined
    }

    // Add profile data if exists
    if (profileData) {
      response.profile = {
        user_id: profileData.user_id,
        name: profileData.name,
        nickname: profileData.nickname,
        date_of_birth: profileData.date_of_birth,
        birth_hour: profileData.birth_hour,
        locale: userData.locale,
        timezone: userData.timezone,
        is_subscriber: userData.is_subscriber,
        created_at: userData.created_at,
        updated_at: profileData.updated_at || userData.created_at
      }
    }

    // Add preferences data if exists
    if (preferencesData && !preferencesError) {
      response.preferences = preferencesData as NotificationPreferences
    }

    // Add subscription data if exists
    if (subscriptionData && !subscriptionError) {
      response.subscription = {
        status: subscriptionData.status,
        renews_at: subscriptionData.renews_at,
        is_subscriber: userData.is_subscriber
      }
    }

    // Log analytics event
    await logAnalyticsEvent(
      supabase,
      'api_me_accessed',
      {
        has_profile: !!response.profile,
        has_preferences: !!response.preferences,
        has_subscription: !!response.subscription,
        is_subscriber: userData.is_subscriber
      },
      user.id
    )

    console.log(`✅ Profile data fetched successfully for user: ${user.id}`)

    return createSuccessResponse(
      response,
      'User profile fetched successfully'
    )

  } catch (error) {
    console.error('Unexpected error in /me endpoint:', error)
    
    if (error.message === 'Unauthorized. Please sign in.') {
      return createErrorResponse(error.message, 401)
    }

    if (error.message.includes('Method') && error.message.includes('not allowed')) {
      return createErrorResponse(error.message, 405)
    }

    return createErrorResponse('Internal server error', 500, error.message)
  }
})

/* 
=============================================================================
USAGE EXAMPLES
=============================================================================

# Get complete user profile
curl -X GET 'https://your-project.supabase.co/functions/v1/me' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json'

# Expected Response
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid-here",
      "email": "user@example.com",
      "created_at": "2024-01-01T00:00:00Z",
      "last_sign_in_at": "2024-01-15T12:00:00Z"
    },
    "profile": {
      "user_id": "uuid-here",
      "name": "John Doe",
      "nickname": "johndoe",
      "date_of_birth": "1990-01-01",
      "birth_hour": 12,
      "locale": "en",
      "timezone": "UTC",
      "is_subscriber": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T00:00:00Z"
    },
    "preferences": {
      "user_id": "uuid-here",
      "frequency": 2,
      "quiet_start": "22:00",
      "quiet_end": "08:00",
      "allow_push": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T00:00:00Z"
    },
    "subscription": {
      "status": "active",
      "renews_at": "2024-02-01T00:00:00Z",
      "is_subscriber": true
    }
  },
  "message": "User profile fetched successfully"
}

=============================================================================
ERROR HANDLING
=============================================================================

# Missing authorization
HTTP 401: { "success": false, "error": "Unauthorized. Please sign in." }

# Wrong method
HTTP 405: { "success": false, "error": "Method POST not allowed. Use GET" }

# Server error
HTTP 500: { "success": false, "error": "Internal server error" }

=============================================================================
*/ 