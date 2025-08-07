// =============================================================================
// DEVICE ENDPOINT - POST /functions/v1/device
// Registers APNs device tokens and manages device information
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  createErrorResponse,
  createSuccessResponse,
  authenticateUser,
  validateMethod,
  validateJsonBody,
  validateDeviceRegistration,
  logAnalyticsEvent,
  type DeviceRegistrationRequest
} from "../../_shared/types.ts"

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate HTTP method
    validateMethod(req, ['POST'])

    // Authenticate user
    const { user, supabase } = await authenticateUser(req)

    // Parse and validate request body
    const body = await validateJsonBody<DeviceRegistrationRequest>(req)

    // Validate device registration data
    const validationErrors = validateDeviceRegistration(body)
    if (validationErrors.length > 0) {
      return createErrorResponse(
        'Validation failed',
        400,
        { errors: validationErrors }
      )
    }

    console.log(`📱 Registering device token for user: ${user.id}`)
    console.log(`Token: ${body.token.substring(0, 8)}...`)

    // Upsert device token
    const { data: deviceData, error: deviceError } = await supabase
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
      return createErrorResponse(
        'Failed to register device token',
        500,
        deviceError
      )
    }

    // Ensure user has notification preferences (create default if not exists)
    const { error: prefsError } = await supabase
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
    const { error: deactivateError } = await supabase
      .from('app_device_tokens')
      .update({ 
        is_active: false, 
        updated_at: new Date().toISOString() 
      })
      .eq('user_id', user.id)
      .neq('token', body.token)

    if (deactivateError) {
      console.error('Error deactivating old tokens:', deactivateError)
      // Don't fail the request, just log the error
    }

    // Log analytics event
    await logAnalyticsEvent(
      supabase,
      'device_token_registered',
      {
        platform: body.platform || 'ios',
        bundle_id: body.bundle_id,
        device_info: body.device_info || null,
        device_id: deviceData.id
      },
      user.id
    )

    console.log(`✅ Device token registered successfully for user: ${user.id}`)

    return createSuccessResponse(
      {
        device_id: deviceData.id,
        message: 'Device token registered successfully'
      },
      'Device registered successfully'
    )

  } catch (error) {
    console.error('Unexpected error in /device endpoint:', error)
    
    if (error.message === 'Unauthorized. Please sign in.') {
      return createErrorResponse(error.message, 401)
    }

    if (error.message.includes('Method') && error.message.includes('not allowed')) {
      return createErrorResponse(error.message, 405)
    }

    if (error.message === 'Invalid JSON body') {
      return createErrorResponse(error.message, 400)
    }

    return createErrorResponse('Internal server error', 500, error.message)
  }
})

/* 
=============================================================================
USAGE EXAMPLES
=============================================================================

# Register a device token
curl -X POST 'https://your-project.supabase.co/functions/v1/device' \
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
  "data": {
    "device_id": "uuid-here",
    "message": "Device token registered successfully"
  },
  "message": "Device registered successfully"
}

=============================================================================
ERROR HANDLING
=============================================================================

# Missing authorization
HTTP 401: { "success": false, "error": "Unauthorized. Please sign in." }

# Wrong method
HTTP 405: { "success": false, "error": "Method GET not allowed. Use POST" }

# Invalid JSON
HTTP 400: { "success": false, "error": "Invalid JSON body" }

# Validation errors
HTTP 400: {
  "success": false,
  "error": "Validation failed",
  "details": {
    "errors": [
      "Token must be a 64-character hexadecimal string",
      "Bundle ID is required and must be a string"
    ]
  }
}

# Server error
HTTP 500: { "success": false, "error": "Internal server error" }

=============================================================================
VALIDATION RULES
=============================================================================

token:
  - Required field
  - Must be exactly 64 hexadecimal characters
  - APNs device token format

bundle_id:
  - Required field
  - Must be a string
  - App bundle identifier (e.g., "deneme.soulbuddy")
  - Maximum 200 characters

platform:
  - Optional field (defaults to "ios")
  - Must be "ios" or "android"

device_info:
  - Optional field
  - Object with optional properties:
    - model: Device model name
    - system_version: OS version
    - app_version: App version

=============================================================================
SIDE EFFECTS
=============================================================================

Device Registration:
  - Upserts device token in app_device_tokens table
  - Deactivates previous tokens for the same user
  - Creates default notification preferences if none exist

Token Management:
  - Only one active token per user
  - Previous tokens marked as inactive
  - Automatic cleanup of old tokens

Preferences:
  - Creates default notification preferences if none exist
  - Does not override existing preferences
  - Sets allow_push to true for new registrations

=============================================================================
*/ 