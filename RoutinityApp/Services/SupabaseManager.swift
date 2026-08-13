//
//  SupabaseManager.swift
//  RoutinityApp
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client: SupabaseClient = {
        let (url, anonKey) = loadCredentials()
        // `FunctionsClient` defaults to a plain `JSONDecoder()`, which can't parse the
        // ISO-8601-with-fractional-seconds timestamps our edge functions return (e.g.
        // `updated_at`/`created_at`), so every response containing a `Date` field fails to
        // decode. Reuse the decoder `PostgrestClient` already ships with proper ISO-8601 support.
        let options = SupabaseClientOptions(
            functions: .init(decoder: PostgrestClient.Configuration.jsonDecoder)
        )
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey, options: options)
    }()

    private static let placeholderURLString = "https://YOUR_PROJECT_REF.supabase.co"
    private static let placeholderAnonKey = "YOUR_SUPABASE_ANON_KEY"

    private static func loadCredentials() -> (url: URL, key: String) {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let urlString = dict["SUPABASE_URL"] as? String,
            let anonKey = dict["SUPABASE_ANON_KEY"] as? String,
            urlString != placeholderURLString,
            anonKey != placeholderAnonKey,
            let url = URL(string: urlString)
        else {
            print("⚠️ Supabase is not configured: copy Secrets.example.plist (repo root) to RoutinityApp/Resources/Secrets.plist and fill in your project URL and anon key.")
            return (URL(string: "https://placeholder.supabase.co")!, "placeholder-anon-key")
        }
        return (url, anonKey)
    }
}
