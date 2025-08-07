// swift-tools-version: 5.9
// This file documents the Swift Package Manager dependencies for SoulBuddy
// Add these packages through Xcode: File > Add Package Dependencies

import PackageDescription

let package = Package(
    name: "SoulBuddy",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SoulBuddy",
            targets: ["SoulBuddy"]
        )
    ],
    dependencies: [
        // Supabase Swift SDK
        .package(
            url: "https://github.com/supabase-community/supabase-swift.git",
            from: "2.5.1"
        ),
        
        // Apple Sign In (part of AuthenticationServices framework)
        // No external dependency needed
        
        // Google Sign In
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS.git",
            from: "7.0.0"
        ),
        
        // CombineExt - Optional utilities for Combine
        .package(
            url: "https://github.com/CombineCommunity/CombineExt.git",
            from: "1.8.1"
        )
    ],
    targets: [
        .target(
            name: "SoulBuddy",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "CombineExt", package: "CombineExt")
            ]
        )
    ]
)

/*
 REQUIRED SWIFT PACKAGES TO ADD IN XCODE:
 
 1. Supabase Swift SDK
    URL: https://github.com/supabase-community/supabase-swift.git
    Version: 2.5.1 or later
    Products: Supabase, PostgREST, GoTrue, Realtime, Storage
 
 2. Google Sign In
    URL: https://github.com/google/GoogleSignIn-iOS.git
    Version: 7.0.0 or later
    Product: GoogleSignIn
 
 3. CombineExt (Optional)
    URL: https://github.com/CombineCommunity/CombineExt.git
    Version: 1.8.1 or later
    Product: CombineExt
    
 APPLE SIGN IN:
 - Uses AuthenticationServices framework (built-in)
 - No external package needed
 - Enable "Sign in with Apple" capability in project settings
 */ 