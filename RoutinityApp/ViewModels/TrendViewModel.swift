//
//  TrendViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

struct DailyTrendPoint: Identifiable {
    let date: Date
    let dailyScore: Int?
    let scores: [ScoreEntry]
    let hadMeal: Bool

    var id: Date { date }

    func entry(for targetType: String) -> ScoreEntry? {
        scores.first { $0.targetType == targetType }
    }
}

/// Fetches `/scores` and `/logs` once per day over a trailing window so the report screens can
/// chart a real trend line and per-goal comparison — the API only returns a single day at a
/// time, so a multi-day view has to be assembled client-side from repeated calls.
@MainActor
final class TrendViewModel: ObservableObject {
    @Published private(set) var points: [DailyTrendPoint] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    // The backend now buckets a "day" as a KST-labeled 기상→취침 session rather than UTC
    // midnight, so every date computed here — the request key, the weekday label, and the
    // trailing-window walk below — has to use KST too or it won't line up with the server's
    // session label.
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    func loadTrend(days: Int) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<days).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        do {
            let fetched = try await withThrowingTaskGroup(of: DailyTrendPoint.self) { group in
                for date in dates {
                    group.addTask { try await self.fetchDay(date) }
                }
                var results: [DailyTrendPoint] = []
                for try await point in group {
                    results.append(point)
                }
                return results
            }
            points = fetched.sorted { $0.date < $1.date }
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    private func fetchDay(_ date: Date) async throws -> DailyTrendPoint {
        let dateKey = Self.dateKeyFormatter.string(from: date)
        async let scoresTask: ScoresResponse = client.functions.invoke(
            "scores",
            options: .init(method: .get, query: [URLQueryItem(name: "date", value: dateKey)])
        )
        async let logsTask: [LogEntry] = client.functions.invoke(
            "logs",
            options: .init(method: .get, query: [URLQueryItem(name: "date", value: dateKey)])
        )
        let (scoresResponse, logs) = try await (scoresTask, logsTask)
        let hadMeal = logs.contains { $0.type == .mealEnd }
        return DailyTrendPoint(date: date, dailyScore: scoresResponse.dailyScore, scores: scoresResponse.scores, hadMeal: hadMeal)
    }

    static func weekdayLabel(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    /// Share of scored days where the given goal type wasn't achieved (not_achieved or missing),
    /// out of days that actually had that goal in place. Returns nil if the goal never appeared.
    func missRate(for targetType: String) -> Double? {
        let entries = points.compactMap { $0.entry(for: targetType) }
        guard !entries.isEmpty else { return nil }
        let missed = entries.filter { $0.status != .achieved }.count
        return Double(missed) / Double(entries.count)
    }

    /// Share of days with no meal logged — meals have no goal/scoring, so this is a
    /// presence-based proxy for "식사 불규칙" rather than a target/actual comparison.
    var mealIrregularityRate: Double? {
        guard !points.isEmpty else { return nil }
        let missed = points.filter { !$0.hadMeal }.count
        return Double(missed) / Double(points.count)
    }
}
