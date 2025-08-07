// =============================================================================
// PROFILE ENDPOINT - PUT /functions/v1/profile
// Updates user profile information (name, nickname, DOB, birth_hour)
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  createErrorResponse,
  createSuccessResponse,
  authenticateUser,
  validateMethod,
  validateJsonBody,
  validateProfileUpdate,
  logAnalyticsEvent,
  type ProfileUpdateRequest
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
    const body = await validateJsonBody<ProfileUpdateRequest>(req)

    // Validate profile data
    const validationErrors = validateProfileUpdate(body)
    if (validationErrors.length > 0) {
      return createErrorResponse(
        'Validation failed',
        400,
        { errors: validationErrors }
      )
    }

    console.log(`👤 Updating profile for user: ${user.id}`)
    console.log('Update data:', { ...body, date_of_birth: body.date_of_birth ? '[REDACTED]' : undefined })

    // Check nickname availability if provided
    if (body.nickname) {
      const { data: nicknameCheck } = await supabase.rpc('check_nickname_availability', {
        p_nickname: body.nickname,
        p_user_id: user.id
      })

      if (!nicknameCheck?.available) {
        return createErrorResponse(
          'Nickname is already taken',
          409,
          { field: 'nickname', value: body.nickname }
        )
      }
    }

    // Update profile using RPC function
    const { data: updatedProfile, error: updateError } = await supabase.rpc('upsert_profile', {
      p_user_id: user.id,
      p_name: body.name || null,
      p_nickname: body.nickname || null,
      p_date_of_birth: body.date_of_birth || null,
      p_birth_hour: body.birth_hour || null
    })

    if (updateError) {
      console.error('Profile update error:', updateError)
      
      // Handle specific database errors
      if (updateError.code === '23505') { // Unique constraint violation
        return createErrorResponse(
          'Nickname is already taken',
          409,
          { field: 'nickname', constraint: 'unique_nickname' }
        )
      }

      return createErrorResponse(
        'Failed to update profile',
        500,
        updateError
      )
    }

    // Fetch the updated complete profile
    const { data: completeProfile, error: fetchError } = await supabase.rpc('get_user_profile')

    if (fetchError) {
      console.error('Failed to fetch updated profile:', fetchError)
      // Still return success since the update worked
    }

    // Log analytics event
    await logAnalyticsEvent(
      supabase,
      'profile_updated',
      {
        fields_updated: Object.keys(body),
        has_name: !!body.name,
        has_nickname: !!body.nickname,
        has_date_of_birth: !!body.date_of_birth,
        has_birth_hour: body.birth_hour !== undefined
      },
      user.id
    )

    console.log(`✅ Profile updated successfully for user: ${user.id}`)

    return createSuccessResponse(
      completeProfile || updatedProfile,
      'Profile updated successfully'
    )

  } catch (error) {
    console.error('Unexpected error in /profile endpoint:', error)
    
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

# Update complete profile
curl -X PUT 'https://your-project.supabase.co/functions/v1/profile' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "John Doe",
    "nickname": "johndoe",
    "date_of_birth": "1990-01-01",
    "birth_hour": 12
  }'

# Update only name
curl -X PUT 'https://your-project.supabase.co/functions/v1/profile' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Jane Smith"
  }'

# Update only nickname
curl -X PUT 'https://your-project.supabase.co/functions/v1/profile' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "nickname": "janesmith"
  }'

# Expected Response
{
  "success": true,
  "data": {
    "user_id": "uuid-here",
    "name": "John Doe",
    "nickname": "johndoe",
    "date_of_birth": "1990-01-01",
    "birth_hour": 12,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T12:00:00Z"
  },
  "message": "Profile updated successfully"
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
      "Name must be a non-empty string",
      "Birth hour must be a number between 0 and 23"
    ]
  }
}

# Nickname taken
HTTP 409: {
  "success": false,
  "error": "Nickname is already taken",
  "details": {
    "field": "nickname",
    "value": "johndoe"
  }
}

# Server error
HTTP 500: { "success": false, "error": "Internal server error" }

=============================================================================
VALIDATION RULES
=============================================================================

name:
  - Must be a non-empty string
  - Maximum 100 characters
  - Optional field

nickname:
  - Must be a non-empty string
  - Maximum 50 characters
  - Only letters, numbers, and underscores allowed
  - Must be unique across all users
  - Optional field

date_of_birth:
  - Must be in YYYY-MM-DD format
  - Must be a valid date
  - Cannot be in the future
  - Optional field

birth_hour:
  - Must be a number between 0 and 23 (inclusive)
  - Represents hour of birth in 24-hour format
  - Optional field

=============================================================================
*/ 