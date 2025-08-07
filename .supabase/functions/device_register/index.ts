// =============================================================================
// DEVICE REGISTRATION EDGE FUNCTION
// Handles APNs token registration and device management
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface DeviceRegistrationRequest {
  token: string
  bundle_id: string
  platform?: string
  device_info?: {
    model?: string
    system_version?: string
    app_version?: string
  }
}

interface DeviceRegistrationResponse {
  success: boolean
  device_id?: string
  message?: string
  error?: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Method not allowed. Use POST.' 
        }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Unauthorized. Please sign in.' 
        }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Parse request body
    const body: DeviceRegistrationRequest = await req.json()

    // Validate required fields
    if (!body.token || !body.bundle_id) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing required fields: token and bundle_id are required.' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Validate token format (APNs tokens should be 64 hex characters)
    const tokenRegex = /^[a-fA-F0-9]{64}$/
    if (!tokenRegex.test(body.token)) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Invalid token format. APNs tokens should be 64 hexadecimal characters.' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Upsert device token
    const { data: deviceData, error: deviceError } = await supabaseClient
      .from('app_device_tokens')
      .upsert({
        user_id: user.id,
        token: body.token,
        bundle_id: body.bundle_id,
        platform: body.platform || 'ios',
        is_active: true,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'token',
        ignoreDuplicates: false
      })
      .select('id')
      .single()

    if (deviceError) {
      console.error('Device token upsert error:', deviceError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Failed to register device token.' 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Ensure user has notification preferences
    const { error: prefsError } = await supabaseClient
      .from('app_notification_preferences')
      .upsert({
        user_id: user.id,
        frequency: 2, // Default to 2 notifications per day
        quiet_start: '22:00',
        quiet_end: '08:00',
        allow_push: true, // User just registered, so they want push notifications
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
        ignoreDuplicates: true // Don't overwrite existing preferences
      })

    if (prefsError) {
      console.error('Notification preferences error:', prefsError)
      // Don't fail the request, just log the error
    }

    // Deactivate old tokens for this user (keep only the latest)
    const { error: deactivateError } = await supabaseClient
      .from('app_device_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('user_id', user.id)
      .neq('token', body.token)

    if (deactivateError) {
      console.error('Error deactivating old tokens:', deactivateError)
      // Don't fail the request, just log the error
    }

    // Log analytics event
    try {
      await supabaseClient.rpc('log_analytics_event', {
        event_name: 'device_registered',
        event_props: {
          platform: body.platform || 'ios',
          bundle_id: body.bundle_id,
          device_info: body.device_info || null,
          timestamp: new Date().toISOString()
        }
      })
    } catch (analyticsError) {
      console.error('Analytics error:', analyticsError)
      // Don't fail the request for analytics errors
    }

    // Return success response
    const response: DeviceRegistrationResponse = {
      success: true,
      device_id: deviceData.id,
      message: 'Device token registered successfully.'
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Unexpected error in device_register:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: 'Internal server error.' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

/* 
=============================================================================
USAGE EXAMPLES
=============================================================================

# Register a device token
curl -X POST 'https://your-project.supabase.co/functions/v1/device_register' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890",
    "bundle_id": "deneme.soulbuddy",
    "platform": "ios",
    "device_info": {
      "model": "iPhone 15",
      "system_version": "17.2",
      "app_version": "1.0.0"
    }
  }'

# Expected Response
{
  "success": true,
  "device_id": "uuid-here",
  "message": "Device token registered successfully."
}

=============================================================================
ERROR HANDLING
=============================================================================

# Missing token
HTTP 400: { "success": false, "error": "Missing required fields: token and bundle_id are required." }

# Invalid token format
HTTP 400: { "success": false, "error": "Invalid token format. APNs tokens should be 64 hexadecimal characters." }

# Unauthorized
HTTP 401: { "success": false, "error": "Unauthorized. Please sign in." }

# Server error
HTTP 500: { "success": false, "error": "Internal server error." }

=============================================================================
*/ 