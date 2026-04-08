import Foundation
import Supabase

// MARK: - Supabase Client Configuration
// Central client singleton — used by AuthManager, SyncService, and all network calls.
// The anon key only grants access allowed by Row Level Security policies.

enum AppSupabase {
    static let url = URL(string: "https://uuqycniicodtquijncph.supabase.co")!

    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1cXljbmlpY29kdHF1aWpuY3BoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2Mjg4OTMsImV4cCI6MjA5MTIwNDg5M30.4Dii5HTrUXVG-yMtfcBUpjSjgXYKtqB8lNSMFZz4i4s"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
