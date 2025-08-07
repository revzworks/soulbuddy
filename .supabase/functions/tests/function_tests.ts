// =============================================================================
// EDGE FUNCTIONS TESTS
// Comprehensive tests for all v1 API endpoints using Deno.test
// =============================================================================

import { assertEquals, assertExists, assertRejects } from "https://deno.land/std@0.208.0/assert/mod.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Test configuration
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'http://localhost:54321'
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'your-anon-key'
const FUNCTION_BASE_URL = `${SUPABASE_URL}/functions/v1`

// Test user credentials (you would set these up in your test environment)
const TEST_USER_EMAIL = 'test@example.com'
const TEST_USER_PASSWORD = 'testpassword123'

// =============================================================================
// Test Utilities
// =============================================================================

async function getAuthToken(): Promise<string> {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  
  const { data, error } = await supabase.auth.signInWithPassword({
    email: TEST_USER_EMAIL,
    password: TEST_USER_PASSWORD
  })

  if (error || !data.session) {
    throw new Error(`Failed to authenticate test user: ${error?.message}`)
  }

  return data.session.access_token
}

async function makeRequest(
  endpoint: string,
  method: string = 'GET',
  body?: any,
  headers: Record<string, string> = {}
): Promise<Response> {
  const url = `${FUNCTION_BASE_URL}${endpoint}`
  
  const requestInit: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers
    }
  }

  if (body && method !== 'GET') {
    requestInit.body = JSON.stringify(body)
  }

  return await fetch(url, requestInit)
}

async function makeAuthenticatedRequest(
  endpoint: string,
  method: string = 'GET',
  body?: any
): Promise<Response> {
  const token = await getAuthToken()
  return makeRequest(endpoint, method, body, {
    'Authorization': `Bearer ${token}`
  })
}

// =============================================================================
// CORS Tests
// =============================================================================

Deno.test("CORS - All endpoints should handle OPTIONS requests", async () => {
  const endpoints = ['/me', '/profile', '/prefs', '/device']
  
  for (const endpoint of endpoints) {
    const response = await makeRequest(endpoint, 'OPTIONS')
    assertEquals(response.status, 200)
    assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*')
    assertExists(response.headers.get('Access-Control-Allow-Headers'))
  }
})

// =============================================================================
// Authentication Tests
// =============================================================================

Deno.test("Auth - Endpoints should require authentication", async () => {
  const endpoints = [
    { path: '/me', method: 'GET' },
    { path: '/profile', method: 'PUT' },
    { path: '/prefs', method: 'PUT' },
    { path: '/device', method: 'POST' }
  ]
  
  for (const endpoint of endpoints) {
    const response = await makeRequest(endpoint.path, endpoint.method, {})
    assertEquals(response.status, 401)
    
    const result = await response.json()
    assertEquals(result.success, false)
    assertEquals(result.error, 'Unauthorized. Please sign in.')
  }
})

// =============================================================================
// Method Validation Tests
// =============================================================================

Deno.test("Method Validation - Wrong HTTP methods should return 405", async () => {
  const token = await getAuthToken()
  
  const testCases = [
    { path: '/me', wrongMethod: 'POST', correctMethod: 'GET' },
    { path: '/profile', wrongMethod: 'GET', correctMethod: 'PUT' },
    { path: '/prefs', wrongMethod: 'GET', correctMethod: 'PUT' },
    { path: '/device', wrongMethod: 'GET', correctMethod: 'POST' }
  ]
  
  for (const testCase of testCases) {
    const response = await makeRequest(testCase.path, testCase.wrongMethod, {}, {
      'Authorization': `Bearer ${token}`
    })
    
    assertEquals(response.status, 405)
    
    const result = await response.json()
    assertEquals(result.success, false)
    assertExists(result.error)
  }
})

// =============================================================================
// /me Endpoint Tests
// =============================================================================

Deno.test("GET /me - Should return user profile data", async () => {
  const response = await makeAuthenticatedRequest('/me')
  assertEquals(response.status, 200)
  
  const result = await response.json()
  assertEquals(result.success, true)
  assertExists(result.data)
  assertExists(result.data.user)
  assertExists(result.data.user.id)
  assertEquals(result.message, 'User profile fetched successfully')
})

Deno.test("GET /me - Should include all expected user data fields", async () => {
  const response = await makeAuthenticatedRequest('/me')
  const result = await response.json()
  
  // User object should exist
  assertExists(result.data.user)
  assertExists(result.data.user.id)
  assertExists(result.data.user.created_at)
  
  // Profile, preferences, and subscription may be null for new users
  // but the fields should exist
  assertEquals(typeof result.data.profile, 'object')
  assertEquals(typeof result.data.preferences, 'object')
  assertEquals(typeof result.data.subscription, 'object')
})

// =============================================================================
// /profile Endpoint Tests
// =============================================================================

Deno.test("PUT /profile - Should update profile with valid data", async () => {
  const profileData = {
    name: "Test User",
    nickname: "testuser123",
    date_of_birth: "1990-01-01",
    birth_hour: 12
  }
  
  const response = await makeAuthenticatedRequest('/profile', 'PUT', profileData)
  assertEquals(response.status, 200)
  
  const result = await response.json()
  assertEquals(result.success, true)
  assertExists(result.data)
  assertEquals(result.message, 'Profile updated successfully')
})

Deno.test("PUT /profile - Should validate required fields", async () => {
  const invalidData = {
    name: "", // Empty name should fail validation
    birth_hour: 25 // Invalid birth hour
  }
  
  const response = await makeAuthenticatedRequest('/profile', 'PUT', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
  assertExists(result.details.errors)
})

Deno.test("PUT /profile - Should handle partial updates", async () => {
  const partialData = {
    name: "Updated Name Only"
  }
  
  const response = await makeAuthenticatedRequest('/profile', 'PUT', partialData)
  assertEquals(response.status, 200)
  
  const result = await response.json()
  assertEquals(result.success, true)
})

Deno.test("PUT /profile - Should reject invalid date format", async () => {
  const invalidData = {
    date_of_birth: "not-a-date"
  }
  
  const response = await makeAuthenticatedRequest('/profile', 'PUT', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

// =============================================================================
// /prefs Endpoint Tests
// =============================================================================

Deno.test("PUT /prefs - Should update notification preferences", async () => {
  const prefsData = {
    frequency: 3,
    quiet_start: "22:00",
    quiet_end: "08:00",
    allow_push: true
  }
  
  const response = await makeAuthenticatedRequest('/prefs', 'PUT', prefsData)
  assertEquals(response.status, 200)
  
  const result = await response.json()
  assertEquals(result.success, true)
  assertExists(result.data.preferences)
  assertEquals(result.data.preferences.frequency, 3)
  assertEquals(result.data.preferences.allow_push, true)
})

Deno.test("PUT /prefs - Should validate frequency range", async () => {
  const invalidData = {
    frequency: 5 // Should be 1-4
  }
  
  const response = await makeAuthenticatedRequest('/prefs', 'PUT', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

Deno.test("PUT /prefs - Should validate time format", async () => {
  const invalidData = {
    quiet_start: "25:00" // Invalid hour
  }
  
  const response = await makeAuthenticatedRequest('/prefs', 'PUT', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

Deno.test("PUT /prefs - Should handle allow_push toggle", async () => {
  // First enable push notifications
  const enableData = { allow_push: true }
  const enableResponse = await makeAuthenticatedRequest('/prefs', 'PUT', enableData)
  assertEquals(enableResponse.status, 200)
  
  // Then disable them
  const disableData = { allow_push: false }
  const disableResponse = await makeAuthenticatedRequest('/prefs', 'PUT', disableData)
  assertEquals(disableResponse.status, 200)
  
  const result = await disableResponse.json()
  assertEquals(result.data.preferences.allow_push, false)
})

// =============================================================================
// /device Endpoint Tests
// =============================================================================

Deno.test("POST /device - Should register device token", async () => {
  const deviceData = {
    token: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890",
    bundle_id: "deneme.soulbuddy",
    platform: "ios",
    device_info: {
      model: "iPhone 15",
      system_version: "17.2",
      app_version: "1.0.0"
    }
  }
  
  const response = await makeAuthenticatedRequest('/device', 'POST', deviceData)
  assertEquals(response.status, 200)
  
  const result = await response.json()
  assertEquals(result.success, true)
  assertExists(result.data.device_id)
  assertEquals(result.message, 'Device registered successfully')
})

Deno.test("POST /device - Should validate token format", async () => {
  const invalidData = {
    token: "invalid-token", // Not 64 hex chars
    bundle_id: "deneme.soulbuddy"
  }
  
  const response = await makeAuthenticatedRequest('/device', 'POST', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

Deno.test("POST /device - Should require bundle_id", async () => {
  const invalidData = {
    token: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890"
    // Missing bundle_id
  }
  
  const response = await makeAuthenticatedRequest('/device', 'POST', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

Deno.test("POST /device - Should handle platform validation", async () => {
  const invalidData = {
    token: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890",
    bundle_id: "deneme.soulbuddy",
    platform: "windows" // Invalid platform
  }
  
  const response = await makeAuthenticatedRequest('/device', 'POST', invalidData)
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Validation failed')
})

// =============================================================================
// Integration Tests
// =============================================================================

Deno.test("Integration - Complete user flow", async () => {
  // 1. Get initial user data
  const meResponse = await makeAuthenticatedRequest('/me')
  assertEquals(meResponse.status, 200)
  
  // 2. Update profile
  const profileData = {
    name: "Integration Test User",
    nickname: "integrationtest"
  }
  const profileResponse = await makeAuthenticatedRequest('/profile', 'PUT', profileData)
  assertEquals(profileResponse.status, 200)
  
  // 3. Update preferences
  const prefsData = {
    frequency: 2,
    allow_push: true
  }
  const prefsResponse = await makeAuthenticatedRequest('/prefs', 'PUT', prefsData)
  assertEquals(prefsResponse.status, 200)
  
  // 4. Register device
  const deviceData = {
    token: "b1c2d3e4f5a6789012345678901234567890123456789012345678901234567890",
    bundle_id: "deneme.soulbuddy"
  }
  const deviceResponse = await makeAuthenticatedRequest('/device', 'POST', deviceData)
  assertEquals(deviceResponse.status, 200)
  
  // 5. Verify updated data
  const finalMeResponse = await makeAuthenticatedRequest('/me')
  const finalResult = await finalMeResponse.json()
  
  assertEquals(finalResult.data.profile.name, "Integration Test User")
  assertEquals(finalResult.data.profile.nickname, "integrationtest")
  assertEquals(finalResult.data.preferences.frequency, 2)
  assertEquals(finalResult.data.preferences.allow_push, true)
})

// =============================================================================
// Error Handling Tests
// =============================================================================

Deno.test("Error Handling - Invalid JSON should return 400", async () => {
  const response = await fetch(`${FUNCTION_BASE_URL}/profile`, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${await getAuthToken()}`,
      'Content-Type': 'application/json'
    },
    body: '{ invalid json }'
  })
  
  assertEquals(response.status, 400)
  
  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error, 'Invalid JSON body')
})

// =============================================================================
// Performance Tests
// =============================================================================

Deno.test("Performance - Endpoints should respond within 2 seconds", async () => {
  const endpoints = [
    { path: '/me', method: 'GET' },
    { path: '/profile', method: 'PUT', body: { name: "Perf Test" } },
    { path: '/prefs', method: 'PUT', body: { frequency: 1 } }
  ]
  
  for (const endpoint of endpoints) {
    const startTime = Date.now()
    const response = await makeAuthenticatedRequest(
      endpoint.path, 
      endpoint.method, 
      endpoint.body
    )
    const endTime = Date.now()
    
    const responseTime = endTime - startTime
    assertEquals(response.status < 500, true, `${endpoint.path} should not return 5xx`)
    assertEquals(responseTime < 2000, true, `${endpoint.path} should respond within 2 seconds, took ${responseTime}ms`)
  }
})

console.log("🧪 All Edge Function tests completed!")

/* 
=============================================================================
RUNNING TESTS
=============================================================================

# Run all tests
deno test --allow-net --allow-env .supabase/functions/tests/

# Run specific test
deno test --allow-net --allow-env .supabase/functions/tests/function_tests.ts

# Run with coverage
deno test --allow-net --allow-env --coverage=coverage .supabase/functions/tests/

# Prerequisites:
1. Set up test user in Supabase Auth
2. Set environment variables:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
3. Ensure database has proper schema (run migrations)
4. Start Supabase functions locally: supabase functions serve

=============================================================================
*/ 