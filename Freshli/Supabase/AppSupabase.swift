import Foundation
import Supabase
import os

// MARK: - Supabase Client Configuration
// Central client singleton — used by AuthManager, SyncService, and all network calls.
//
// SECURITY NOTE: The anon key is safe to ship in the app.
// - It's a JWT with a fixed expiry date and limited scope
// - It only grants access allowed by Row Level Security (RLS) policies
// - All data access is controlled by RLS, not by the key itself
// - The key is public by design and cannot leak sensitive data
// - Critical operations (auth, profile deletion) use server-side RPC functions

// `nonisolated` at enum level so these statics are accessible from any
// actor context (services with `nonisolated init()`, off-actor background tasks,
// etc.). The values are immutable `let`s of Sendable types, so this is safe.
nonisolated enum AppSupabase {
    static let url = URL(string: "https://uuqycniicodtquijncph.supabase.co")!

    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1cXljbmlpY29kdHF1aWpuY3BoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2Mjg4OTMsImV4cCI6MjA5MTIwNDg5M30.4Dii5HTrUXVG-yMtfcBUpjSjgXYKtqB8lNSMFZz4i4s"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                // Emit the locally cached session immediately on launch rather than
                // waiting for a network refresh — silences the SDK deprecation warning
                // and makes cold-start auth faster.
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}

// MARK: - Debug Logging Helper
// Use this for verbose logging in DEBUG builds only
#if DEBUG
func debugLog(_ message: String) {
    PSLogger.general.debug(message)
}
#else
func debugLog(_ message: String) {
    // No-op in Release builds
}
#endif
