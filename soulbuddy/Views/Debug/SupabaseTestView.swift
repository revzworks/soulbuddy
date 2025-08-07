import SwiftUI
import Combine

struct SupabaseTestView: View {
    @EnvironmentObject var supabaseClientManager: SupabaseClientManager
    @State private var healthResult: HealthCheckResult?
    @State private var isTestingConnection = false
    @State private var testResults: [TestResult] = []
    
    var body: some View {
        NavigationView {
            List {
                connectionStatusSection
                testResultsSection
                actionsSection
            }
            .navigationTitle("Supabase Test")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await runAllTests()
            }
        }
        .task {
            await runAllTests()
        }
    }
    
    // MARK: - Connection Status Section
    private var connectionStatusSection: some View {
        Section("Connection Status") {
            HStack {
                Circle()
                    .fill(supabaseClientManager.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(supabaseClientManager.isConnected ? "Connected" : "Disconnected")
                    .font(Theme.Typography.body)
                
                Spacer()
                
                if supabaseClientManager.isInitialized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let error = supabaseClientManager.connectionError {
                Text("Error: \(error.localizedDescription)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            // Configuration details
            VStack(alignment: .leading, spacing: 4) {
                Text("Environment: \(SupabaseConfig.shared.environment)")
                Text("URL: \(SupabaseConfig.shared.url.absoluteString)")
                Text("Key: \(SupabaseConfig.shared.anonKey.prefix(20))...")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.textSecondary)
        }
    }
    
    // MARK: - Test Results Section
    private var testResultsSection: some View {
        Section("Test Results") {
            if testResults.isEmpty {
                Text("No tests run yet")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            } else {
                ForEach(testResults, id: \.name) { result in
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(Theme.Typography.body)
                            
                            Text(result.message)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(result.duration, format: .number.precision(.fractionLength(2)))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        Section("Actions") {
            Button("Run Health Check") {
                Task {
                    await runHealthCheck()
                }
            }
            .disabled(isTestingConnection)
            
            Button("Test Server Time") {
                Task {
                    await testServerTime()
                }
            }
            .disabled(isTestingConnection)
            
            Button("Test Analytics Logging") {
                Task {
                    await testAnalyticsLogging()
                }
            }
            .disabled(isTestingConnection)
            
            Button("Run All Tests") {
                Task {
                    await runAllTests()
                }
            }
            .disabled(isTestingConnection)
            
            if isTestingConnection {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing...")
                        .font(Theme.Typography.caption)
                }
            }
        }
    }
    
    // MARK: - Test Methods
    private func runAllTests() async {
        isTestingConnection = true
        testResults.removeAll()
        
        await runHealthCheck()
        await testServerTime()
        await testAnalyticsLogging()
        
        isTestingConnection = false
    }
    
    private func runHealthCheck() async {
        let startTime = Date()
        
        do {
            let result = await supabaseClientManager.performHealthCheck()
            let duration = Date().timeIntervalSince(startTime)
            
            testResults.append(TestResult(
                name: "Health Check",
                success: result.isHealthy,
                message: result.isHealthy ? "All services healthy" : "Some services have issues",
                duration: duration
            ))
            
            healthResult = result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            testResults.append(TestResult(
                name: "Health Check",
                success: false,
                message: "Error: \(error.localizedDescription)",
                duration: duration
            ))
        }
    }
    
    private func testServerTime() async {
        let startTime = Date()
        
        do {
            let client = try supabaseClientManager.getClient()
            let response: [String: Any] = try await client.database
                .rpc("get_server_time")
                .execute()
                .value
            
            let duration = Date().timeIntervalSince(startTime)
            
            if let serverTime = response["server_time"] as? String {
                testResults.append(TestResult(
                    name: "Server Time",
                    success: true,
                    message: "Server time: \(serverTime)",
                    duration: duration
                ))
            } else {
                testResults.append(TestResult(
                    name: "Server Time",
                    success: true,
                    message: "Response received",
                    duration: duration
                ))
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            testResults.append(TestResult(
                name: "Server Time",
                success: false,
                message: "Error: \(error.localizedDescription)",
                duration: duration
            ))
        }
    }
    
    private func testAnalyticsLogging() async {
        let startTime = Date()
        
        do {
            let client = try supabaseClientManager.getClient()
            let response: [String: Any] = try await client.database
                .rpc("log_analytics_event", params: [
                    "event_name": "test_event",
                    "event_props": [
                        "test_source": "debug_view",
                        "timestamp": ISO8601DateFormatter().string(from: Date())
                    ]
                ])
                .execute()
                .value
            
            let duration = Date().timeIntervalSince(startTime)
            
            if let success = response["success"] as? Bool, success {
                testResults.append(TestResult(
                    name: "Analytics Logging",
                    success: true,
                    message: "Event logged successfully",
                    duration: duration
                ))
            } else {
                testResults.append(TestResult(
                    name: "Analytics Logging",
                    success: false,
                    message: "Logging failed: \(response)",
                    duration: duration
                ))
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            testResults.append(TestResult(
                name: "Analytics Logging",
                success: false,
                message: "Error: \(error.localizedDescription)",
                duration: duration
            ))
        }
    }
}

// MARK: - Test Result Model
struct TestResult {
    let name: String
    let success: Bool
    let message: String
    let duration: TimeInterval
}

// MARK: - Preview
#Preview {
    SupabaseTestView()
        .environmentObject(SupabaseClientManager.shared)
} 