//
//  LogsViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var isRecording: LogEntry.LogType?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    func recordLog(type: LogEntry.LogType, userId: UUID) async {
        errorMessage = nil
        isRecording = type
        defer { isRecording = nil }

        do {
            try await client
                .from("logs")
                .insert(NewLogEntry(userId: userId, type: type.rawValue))
                .execute()
            await loadLogs(on: Date(), userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLogs(on date: Date, userId: UUID) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)
            let logs: [LogEntry] = try await client
                .from("logs")
                .select()
                .eq("user_id", value: userId)
                .gte("logged_at", value: startOfDay)
                .lt("logged_at", value: startOfNextDay)
                .order("logged_at", ascending: false)
                .execute()
                .value
            self.logs = logs
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
