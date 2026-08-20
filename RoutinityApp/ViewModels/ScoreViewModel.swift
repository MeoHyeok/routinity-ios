//
//  ScoreViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class ScoreViewModel: ObservableObject {
    @Published private(set) var scores: [ScoreEntry] = []
    @Published private(set) var dailyScore: Int?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    // The backend now buckets a "day" as a KST-labeled 기상→취침 session rather than UTC
    // midnight, so the date param we request has to be computed in KST too or it won't line up
    // with the server's session label.
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    func refreshTodayScore() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let dateKey = Self.dateKeyFormatter.string(from: Date())
            let response: ScoresResponse = try await loggedInvoke("GET /scores?date=\(dateKey)") {
                try await client.functions.invoke(
                    "scores",
                    options: .init(method: .get, query: [URLQueryItem(name: "date", value: dateKey)])
                )
            }
            scores = response.scores
            dailyScore = response.dailyScore
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }
}
