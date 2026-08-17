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

        let request = NewLogRequest(type: type.rawValue, timestamp: Self.isoFormatter.string(from: Date()))

        do {
            let _: LogEntry = try await client.functions.invoke("logs", options: .init(body: request))
            await loadLogs(on: Date())
        } catch {
            // Edge Functions cold-start after a few idle minutes, which surfaces as a transient
            // 502/relay error on exactly the tap that's most likely to be the day's first —
            // pressing 기상 right after opening the app. One quiet retry absorbs that instead of
            // leaving the quick-log button looking like it silently did nothing.
            guard isTransient(error) else {
                errorMessage = friendlyErrorMessage(error)
                return
            }
            do {
                try await Task.sleep(nanoseconds: 800_000_000)
                let _: LogEntry = try await client.functions.invoke("logs", options: .init(body: request))
                await loadLogs(on: Date())
            } catch {
                errorMessage = friendlyErrorMessage(error)
            }
        }
    }

    private func isTransient(_ error: Error) -> Bool {
        switch error {
        case FunctionsError.relayError:
            return true
        case FunctionsError.httpError(let code, _):
            return code >= 500
        default:
            return (error as? URLError)?.code != nil
        }
    }

    func deleteLog(id: UUID) async {
        errorMessage = nil

        do {
            try await client.functions.invoke(
                "logs",
                options: .init(method: .delete, query: [URLQueryItem(name: "id", value: id.uuidString)])
            )
            logs.removeAll { $0.id == id }
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
