//
//  ScoreViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class ScoreViewModel: ObservableObject {
    @Published private(set) var score: Score?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    /// Recomputes today's score from `logs` + `goals` and stores it in `scores`.
    func refreshTodayScore(userId: UUID) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let today = Date()
            async let logsTask = loadTodaysLogs(userId: userId, on: today)
            async let goalsTask = loadGoals(userId: userId)
            let (logs, goals) = try await (logsTask, goalsTask)

            let wakeGoal = goals.first { $0.targetType == .wake }
            let studyGoal = goals.first { $0.targetType == .studyMinutes }

            let wakeComponent = wakeGoal.flatMap { wakeScore(for: logs, goal: $0, on: today) }
            let studyComponent = studyGoal.flatMap { studyScore(for: logs, goal: $0) }

            let components = [wakeComponent, studyComponent].compactMap { $0 }
            guard !components.isEmpty else {
                score = nil
                return
            }
            let overall = components.reduce(0, +) / components.count

            let upsert = ScoreUpsert(
                userId: userId,
                scoreDate: Self.dateKeyFormatter.string(from: today),
                score: overall,
                wakeScore: wakeComponent,
                studyScore: studyComponent
            )
            let saved: Score = try await client
                .from("scores")
                .upsert(upsert, onConflict: "user_id,score_date")
                .select()
                .single()
                .execute()
                .value
            score = saved
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Data loading

    private func loadTodaysLogs(userId: UUID, on date: Date) async throws -> [LogEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)
        return try await client
            .from("logs")
            .select()
            .eq("user_id", value: userId)
            .gte("logged_at", value: startOfDay)
            .lt("logged_at", value: startOfNextDay)
            .order("logged_at", ascending: true)
            .execute()
            .value
    }

    private func loadGoals(userId: UUID) async throws -> [Goal] {
        try await client
            .from("goals")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    // MARK: - Scoring

    /// 100 if the first wake-up log is at or before the goal time, decaying by 1 point per minute late.
    private func wakeScore(for logs: [LogEntry], goal: Goal, on date: Date) -> Int? {
        guard let wakeLog = logs.first(where: { $0.type == .wake }) else { return nil }
        guard let targetTime = Self.time(fromHHmm: goal.targetValue, on: date) else { return nil }

        let lateMinutes = Int(wakeLog.loggedAt.timeIntervalSince(targetTime) / 60)
        return max(0, 100 - max(0, lateMinutes))
    }

    /// Ratio of completed study minutes (paired study_start/study_end) to the goal, capped at 100.
    private func studyScore(for logs: [LogEntry], goal: Goal) -> Int? {
        guard let targetMinutes = Int(goal.targetValue), targetMinutes > 0 else { return nil }

        var totalMinutes = 0
        var openStart: Date?
        for log in logs {
            switch log.type {
            case .studyStart:
                openStart = log.loggedAt
            case .studyEnd:
                if let start = openStart {
                    totalMinutes += Int(log.loggedAt.timeIntervalSince(start) / 60)
                    openStart = nil
                }
            case .wake, .meal:
                continue
            }
        }

        let ratio = min(Double(totalMinutes) / Double(targetMinutes), 1.0)
        return Int(ratio * 100)
    }

    private static func time(fromHHmm string: String, on date: Date) -> Date? {
        let parts = string.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }
}
