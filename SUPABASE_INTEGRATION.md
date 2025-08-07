# Supabase Integration Guide

This document explains the Supabase client integration for SoulBuddy iOS app.

## Overview

The app uses a centralized Supabase client management system with:
- ✅ Configuration loading from `.xcconfig` files
- ✅ Singleton client manager with dependency injection
- ✅ Automatic authentication initialization
- ✅ Connection health monitoring
- ✅ Analytics event logging
- ✅ Debug testing interface

## Components

### 1. SupabaseConfig.swift
Handles configuration loading and validation:
- Loads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist
- Validates configuration format and security
- Provides environment-specific settings

### 2. SupabaseClientManager.swift
Main client manager with DI container:
- Singleton pattern for app-wide access
- Automatic client initialization
- Connection testing and health checks
- Analytics event logging
- Observable properties for UI updates

### 3. Database Functions (SQL)
Run `Database/Analytics.sql` in your Supabase SQL Editor to create:

```sql
-- Required functions for the iOS app
log_analytics_event(event_name, event_props, event_user_id)
get_server_time()
health_check()
```

## Setup Instructions

### 1. Database Setup
1. Open your Supabase project dashboard
2. Go to SQL Editor
3. Run the SQL from `Database/Analytics.sql`
4. Verify functions are created successfully

### 2. iOS Configuration
Configuration is already set in `.xcconfig` files:
- **Development**: Uses your Supabase instance
- **Staging**: Same instance, different bundle ID
- **Production**: Same instance, production settings

### 3. Swift Package Dependencies
Add these packages in Xcode (`File > Add Package Dependencies`):

```
https://github.com/supabase-community/supabase-swift.git
```

## Usage

### Basic Client Access
```swift
// Get client instance
let client = try SupabaseClientManager.shared.getClient()

// Use database
let result = try await client.database
    .from("table_name")
    .select()
    .execute()
```

### Dependency Injection
```swift
// In SwiftUI views
@EnvironmentObject var supabaseClientManager: SupabaseClientManager

// Check connection status
if supabaseClientManager.isConnected {
    // Perform operations
}
```

### Analytics Logging
```swift
// Automatically logs app_open event on launch
// Custom events:
let response = try await client.database
    .rpc("log_analytics_event", params: [
        "event_name": "custom_event",
        "event_props": ["key": "value"]
    ])
    .execute()
```

## Testing & Debugging

### Debug View (Development Only)
- Access via "Debug" button in development builds
- Tests connection, server time, and analytics logging
- Shows real-time connection status
- Displays configuration details

### Health Checks
```swift
let healthResult = await supabaseClientManager.performHealthCheck()
print("Health: \(healthResult.isHealthy)")
```

### Console Logging
The app logs detailed information in development:
```
✅ Supabase Configuration Loaded:
   Environment: Development
   URL: https://qvgitnefikrhavhlaadl.supabase.co
   Anon Key: eyJhbGciOiJIUzI1NiIs...

✅ Supabase client initialized successfully
✅ Supabase connection test successful
📊 App open event logged successfully
🏥 Health Check: ✅ Healthy
```

## Architecture

```
SoulBuddyApp
├── SupabaseConfig (Configuration)
├── SupabaseClientManager (Client + DI)
├── SupabaseService (Legacy wrapper, updated)
└── SupabaseTestView (Debug interface)
```

## Features

### ✅ Implemented
- [x] Configuration management (.xcconfig → Info.plist → Swift)
- [x] Client initialization with proper options
- [x] Auth initialization (`supabase.auth.initialize()`)
- [x] Connection testing with fallback
- [x] Analytics logging via RPC
- [x] Health monitoring
- [x] Debug interface
- [x] Environment-specific logging
- [x] Error handling and recovery

### 🔄 Automatic Behaviors
- **App Launch**: Initializes client, tests connection, logs app_open event
- **Development**: Shows debug button, detailed logging, health checks
- **Production**: Minimal logging, optimized performance
- **Connection Issues**: Graceful degradation, retry logic

## Security Notes

- ✅ Uses HTTPS-only connections
- ✅ Validates JWT format for anon keys
- ✅ Logs safe configuration info (truncated keys)
- ✅ Proper error handling without exposing secrets
- ✅ Environment-specific security levels

## Error Handling

The integration includes comprehensive error handling:
- Configuration validation errors
- Network connection issues
- Database query failures
- Analytics logging failures (non-blocking)

All errors are logged appropriately based on environment settings.

## Performance

- Singleton pattern minimizes client creation overhead
- Lazy initialization prevents blocking app launch
- Connection pooling via Supabase client
- Efficient health checks with caching
- Background analytics logging

## Troubleshooting

### Common Issues

1. **"No such module 'Supabase'"**
   - Add Supabase Swift package in Xcode
   - Ensure package is added to target

2. **Configuration errors**
   - Check `.xcconfig` files have correct values
   - Verify scheme uses correct `.xcconfig` file

3. **Connection failures**
   - Check network connectivity
   - Verify Supabase URL is accessible
   - Check anon key validity

4. **Analytics logging fails**
   - Run `Database/Analytics.sql` in Supabase
   - Check RLS policies allow function execution

### Debug Steps
1. Enable Development configuration
2. Check console logs for detailed errors
3. Use Debug view to test individual components
4. Run health check to identify specific issues

## Next Steps

After integration is complete, you can:
1. Add authentication flows
2. Implement data synchronization
3. Add real-time features
4. Expand analytics tracking
5. Add offline capabilities 