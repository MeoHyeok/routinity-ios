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
    private static let isoFormatter = ISO8601DateFormatter()

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    func recordLog(type: LogEntry.LogType) async {
        errorMessage = nil
        isRecording = type
        defer { isRecording = nil }

        do {
            let request = NewLogRequest(type: type.rawValue, timestamp: Self.isoFormatter.string(from: Date()))
            let _: LogEntry = try await client.functions.invoke("logs", options: .init(body: request))
            await loadLogs(on: Date())
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func loadLogs(on date: Date) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let dateKey = Self.dateKeyFormatter.string(from: date)
            let logs: [LogEntry] = try await client.functions.invoke(
                "logs",
                options: .init(method: .get, query: [URLQueryItem(name: "date", value: dateKey)])
            )
            self.logs = logs
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }
}
