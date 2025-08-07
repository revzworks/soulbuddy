// =============================================================================
// SHARED TYPES AND UTILITIES FOR SUPABASE EDGE FUNCTIONS
// =============================================================================

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

// =============================================================================
// CORS Headers
// =============================================================================

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
}

// =============================================================================
// Response Helpers
// =============================================================================

export function createResponse(
  data: any,
  status: number = 200,
  headers: Record<string, string> = {}
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        ...headers
      }
    }
  )
}

export function createErrorResponse(
  error: string,
  status: number = 400,
  details?: any
): Response {
  return createResponse(
    {
      success: false,
      error,
      details
    },
    status
  )
}

export function createSuccessResponse(
  data: any,
  message?: string
): Response {
  return createResponse({
    success: true,
    data,
    message
  })
}

// =============================================================================
// Supabase Client Setup
// =============================================================================

export function createSupabaseClient(request: Request): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: {
        headers: { Authorization: request.headers.get('Authorization')! },
      },
    }
  )
}

// =============================================================================
// Authentication Helper
// =============================================================================

export async function authenticateUser(request: Request) {
  const supabase = createSupabaseClient(request)
  
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError || !user) {
    throw new Error('Unauthorized. Please sign in.')
  }

  return { user, supabase }
}

// =============================================================================
// Request Validation
// =============================================================================

export async function validateJsonBody<T>(request: Request): Promise<T> {
  try {
    const body = await request.json()
    return body as T
  } catch (error) {
    throw new Error('Invalid JSON body')
  }
}

export function validateMethod(request: Request, allowedMethods: string[]): void {
  if (!allowedMethods.includes(request.method)) {
    throw new Error(`Method ${request.method} not allowed. Use ${allowedMethods.join(', ')}`)
  }
}

// =============================================================================
// Analytics Helper
// =============================================================================

export async function logAnalyticsEvent(
  supabase: SupabaseClient,
  eventName: string,
  eventProps: Record<string, any> = {},
  userId?: string
): Promise<void> {
  try {
    await supabase.rpc('log_analytics_event', {
      event_name: eventName,
      event_props: {
        ...eventProps,
        timestamp: new Date().toISOString(),
        endpoint: eventName.includes('_') ? eventName.split('_')[0] : eventName
      },
      event_user_id: userId
    })
  } catch (error) {
    console.warn('Failed to log analytics event:', error)
    // Don't throw - analytics failures shouldn't break the main flow
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

// User Profile Models
export interface UserProfile {
  user_id: string
  name?: string
  nickname?: string
  date_of_birth?: string
  birth_hour?: number
  locale: string
  timezone: string
  is_subscriber: boolean
  created_at: string
  updated_at: string
}

export interface ProfileUpdateRequest {
  name?: string
  nickname?: string
  date_of_birth?: string
  birth_hour?: number
}

// Notification Preferences Models
export interface NotificationPreferences {
  user_id: string
  frequency: number
  quiet_start: string
  quiet_end: string
  allow_push: boolean
  created_at: string
  updated_at: string
}

export interface PreferencesUpdateRequest {
  frequency?: number
  quiet_start?: string
  quiet_end?: string
  allow_push?: boolean
}

// Device Registration Models
export interface DeviceRegistrationRequest {
  token: string
  bundle_id: string
  platform?: string
  device_info?: {
    model?: string
    system_version?: string
    app_version?: string
  }
}

// API Response Models
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  message?: string
  error?: string
  details?: any
}

export interface UserMeResponse {
  user: {
    id: string
    email?: string
    created_at: string
    last_sign_in_at?: string
  }
  profile?: UserProfile
  preferences?: NotificationPreferences
  subscription?: {
    status: string
    renews_at?: string
    is_subscriber: boolean
  }
}

// =============================================================================
// VALIDATION HELPERS
// =============================================================================

export function validateProfileUpdate(data: ProfileUpdateRequest): string[] {
  const errors: string[] = []

  if (data.name !== undefined) {
    if (typeof data.name !== 'string' || data.name.trim().length === 0) {
      errors.push('Name must be a non-empty string')
    } else if (data.name.length > 100) {
      errors.push('Name must be less than 100 characters')
    }
  }

  if (data.nickname !== undefined) {
    if (typeof data.nickname !== 'string' || data.nickname.trim().length === 0) {
      errors.push('Nickname must be a non-empty string')
    } else if (data.nickname.length > 50) {
      errors.push('Nickname must be less than 50 characters')
    } else if (!/^[a-zA-Z0-9_]+$/.test(data.nickname)) {
      errors.push('Nickname can only contain letters, numbers, and underscores')
    }
  }

  if (data.date_of_birth !== undefined) {
    if (typeof data.date_of_birth !== 'string') {
      errors.push('Date of birth must be a string in YYYY-MM-DD format')
    } else {
      const dateRegex = /^\d{4}-\d{2}-\d{2}$/
      if (!dateRegex.test(data.date_of_birth)) {
        errors.push('Date of birth must be in YYYY-MM-DD format')
      } else {
        const date = new Date(data.date_of_birth)
        if (isNaN(date.getTime())) {
          errors.push('Invalid date of birth')
        } else if (date > new Date()) {
          errors.push('Date of birth cannot be in the future')
        }
      }
    }
  }

  if (data.birth_hour !== undefined) {
    if (typeof data.birth_hour !== 'number' || data.birth_hour < 0 || data.birth_hour > 23) {
      errors.push('Birth hour must be a number between 0 and 23')
    }
  }

  return errors
}

export function validatePreferencesUpdate(data: PreferencesUpdateRequest): string[] {
  const errors: string[] = []

  if (data.frequency !== undefined) {
    if (typeof data.frequency !== 'number' || data.frequency < 1 || data.frequency > 4) {
      errors.push('Frequency must be a number between 1 and 4')
    }
  }

  if (data.quiet_start !== undefined) {
    if (typeof data.quiet_start !== 'string' || !/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(data.quiet_start)) {
      errors.push('Quiet start must be in HH:MM format (24-hour)')
    }
  }

  if (data.quiet_end !== undefined) {
    if (typeof data.quiet_end !== 'string' || !/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(data.quiet_end)) {
      errors.push('Quiet end must be in HH:MM format (24-hour)')
    }
  }

  if (data.allow_push !== undefined) {
    if (typeof data.allow_push !== 'boolean') {
      errors.push('Allow push must be a boolean')
    }
  }

  return errors
}

export function validateDeviceRegistration(data: DeviceRegistrationRequest): string[] {
  const errors: string[] = []

  if (!data.token || typeof data.token !== 'string') {
    errors.push('Token is required and must be a string')
  } else if (!/^[a-fA-F0-9]{64}$/.test(data.token)) {
    errors.push('Token must be a 64-character hexadecimal string')
  }

  if (!data.bundle_id || typeof data.bundle_id !== 'string') {
    errors.push('Bundle ID is required and must be a string')
  } else if (data.bundle_id.length > 200) {
    errors.push('Bundle ID must be less than 200 characters')
  }

  if (data.platform !== undefined) {
    if (typeof data.platform !== 'string' || !['ios', 'android'].includes(data.platform)) {
      errors.push('Platform must be "ios" or "android"')
    }
  }

  return errors
} 