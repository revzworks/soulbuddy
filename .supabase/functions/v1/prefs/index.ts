// =============================================================================
// PREFS ENDPOINT - PUT /functions/v1/prefs
// Updates user notification preferences (frequency, quiet hours, allow_push)
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  createErrorResponse,
  createSuccessResponse,
  authenticateUser,
  validateMethod,
  validateJsonBody,
  validatePreferencesUpdate,
  logAnalyticsEvent,
  type PreferencesUpdateRequest,
  type NotificationPreferences
} from "../../_shared/types.ts"

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Validate HTTP method
    validateMethod(req, ['PUT'])

    // Authenticate user
    const { user, supabase } = await authenticateUser(req)

    // Parse and validate request body
    const body = await validateJsonBody<PreferencesUpdateRequest>(req)

    // Validate preferences data
    const validationErrors = validatePreferencesUpdate(body)
    if (validationErrors.length > 0) {
      return createErrorResponse(
        'Validation failed',
        400,
        { errors: validationErrors }
      )
    }

    console.log(`🔔 Updating notification preferences for user: ${user.id}`)
    console.log('Update data:', body)

    // Prepare update data
    const updateData: Partial<NotificationPreferences> = {
      user_id: user.id,
      updated_at: new Date().toISOString()
    }

    // Add fields that are being updated
    if (body.frequency !== undefined) {
      updateData.frequency = body.frequency
    }
    if (body.quiet_start !== undefined) {
      updateData.quiet_start = body.quiet_start
    }
    if (body.quiet_end !== undefined) {
      updateData.quiet_end = body.quiet_end
    }
    if (body.allow_push !== undefined) {
      updateData.allow_push = body.allow_push
    }

    // Upsert notification preferences
    const { data: updatedPrefs, error: updateError } = await supabase
      .from('app_notification_preferences')
      .upsert(updateData, {
        onConflict: 'user_id',
        ignoreDuplicates: false
      })
      .select('*')
      .single()

    if (updateError) {
      console.error('Preferences update error:', updateError)
      return createErrorResponse(
        'Failed to update notification preferences',
        500,
        updateError
      )
    }

    // Validate quiet hours logic (optional warning)
    let warnings: string[] = []
    if (updatedPrefs.quiet_start && updatedPrefs.quiet_end) {
      const startHour = parseInt(updatedPrefs.quiet_start.split(':')[0])
      const endHour = parseInt(updatedPrefs.quiet_end.split(':')[0])
      
      // Check for reasonable quiet hours (example: warn if quiet period is > 14 hours)
      if (startHour < endHour && (endHour - startHour) > 14) {
        warnings.push('Quiet period is longer than 14 hours - you may miss important notifications')
      } else if (startHour > endHour && (24 - startHour + endHour) > 14) {
        warnings.push('Quiet period is longer than 14 hours - you may miss important notifications')
      }
    }

    // If push notifications were disabled, deactivate device tokens
    if (body.allow_push === false) {
      const { error: tokenError } = await supabase
        .from('app_device_tokens')
        .update({ 
          is_active: false,
          updated_at: new Date().toISOString()
        })
        .eq('user_id', user.id)

      if (tokenError) {
        console.warn('Failed to deactivate device tokens:', tokenError)
        warnings.push('Push notifications disabled but device tokens may still be active')
      }
    }

    // If push notifications were re-enabled, we should reactivate the most recent token
    if (body.allow_push === true) {
      const { data: recentToken, error: tokenFetchError } = await supabase
        .from('app_device_tokens')
        .select('id')
        .eq('user_id', user.id)
        .order('updated_at', { ascending: false })
        .limit(1)
        .single()

      if (recentToken && !tokenFetchError) {
        const { error: reactivateError } = await supabase
          .from('app_device_tokens')
          .update({ 
            is_active: true,
            updated_at: new Date().toISOString()
          })
          .eq('id', recentToken.id)

        if (reactivateError) {
          console.warn('Failed to reactivate device token:', reactivateError)
          warnings.push('Push notifications enabled but device token may not be active')
        }
      }
    }

    // Log analytics event
    await logAnalyticsEvent(
      supabase,
      'notification_preferences_updated',
      {
        fields_updated: Object.keys(body),
        frequency: updatedPrefs.frequency,
        allow_push: updatedPrefs.allow_push,
        has_quiet_hours: !!(updatedPrefs.quiet_start && updatedPrefs.quiet_end),
        warnings_count: warnings.length
      },
      user.id
    )

    console.log(`✅ Notification preferences updated successfully for user: ${user.id}`)

    const response = {
      preferences: updatedPrefs,
      warnings: warnings.length > 0 ? warnings : undefined
    }

    return createSuccessResponse(
      response,
      'Notification preferences updated successfully'
    )

  } catch (error) {
    console.error('Unexpected error in /prefs endpoint:', error)
    
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

# Update all preferences
curl -X PUT 'https://your-project.supabase.co/functions/v1/prefs' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "frequency": 3,
    "quiet_start": "23:00",
    "quiet_end": "07:00",
    "allow_push": true
  }'

# Update only frequency
curl -X PUT 'https://your-project.supabase.co/functions/v1/prefs' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "frequency": 4
  }'

# Disable push notifications
curl -X PUT 'https://your-project.supabase.co/functions/v1/prefs' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "allow_push": false
  }'

# Expected Response
{
  "success": true,
  "data": {
    "preferences": {
      "user_id": "uuid-here",
      "frequency": 3,
      "quiet_start": "23:00",
      "quiet_end": "07:00",
      "allow_push": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T12:00:00Z"
    },
    "warnings": [
      "Quiet period is longer than 14 hours - you may miss important notifications"
    ]
  },
  "message": "Notification preferences updated successfully"
}

=============================================================================
ERROR HANDLING
=============================================================================

# Missing authorization
HTTP 401: { "success": false, "error": "Unauthorized. Please sign in." }

# Wrong method
HTTP 405: { "success": false, "error": "Method GET not allowed. Use PUT" }

# Invalid JSON
HTTP 400: { "success": false, "error": "Invalid JSON body" }

# Validation errors
HTTP 400: {
  "success": false,
  "error": "Validation failed",
  "details": {
    "errors": [
      "Frequency must be a number between 1 and 4",
      "Quiet start must be in HH:MM format (24-hour)"
    ]
  }
}

# Server error
HTTP 500: { "success": false, "error": "Internal server error" }

=============================================================================
VALIDATION RULES
=============================================================================

frequency:
  - Must be a number between 1 and 4 (inclusive)
  - Represents notifications per day
  - Optional field

quiet_start:
  - Must be in HH:MM format (24-hour)
  - Example: "22:00" for 10:00 PM
  - Optional field

quiet_end:
  - Must be in HH:MM format (24-hour)
  - Example: "08:00" for 8:00 AM
  - Can be earlier than quiet_start (spans midnight)
  - Optional field

allow_push:
  - Must be a boolean (true/false)
  - When set to false, deactivates device tokens
  - When set to true, reactivates most recent device token
  - Optional field

=============================================================================
SIDE EFFECTS
=============================================================================

When allow_push is set to false:
  - All device tokens for the user are marked as inactive
  - User will stop receiving push notifications

When allow_push is set to true:
  - Most recent device token is reactivated
  - User will resume receiving push notifications
  - May need to re-register device token if none exist

=============================================================================
*/ 