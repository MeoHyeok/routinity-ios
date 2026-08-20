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
    /// Whether `logs` is actually yesterday's still-open session rather than today's — see
    /// `loadTodayIncludingCarryover`.
    @Published private(set) var isCarryoverSession = false

    private let client = SupabaseManager.client
    private static let isoFormatter = ISO8601DateFormatter()

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

    func recordLog(type: LogEntry.LogType) async {
        errorMessage = nil
        isRecording = type
        defer { isRecording = nil }

        let request = NewLogRequest(type: type.rawValue, timestamp: Self.isoFormatter.string(from: Date()))

        do {
            let _: LogEntry = try await client.functions.invoke("logs", options: .init(body: request))
            await loadTodayIncludingCarryover()
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
                await loadTodayIncludingCarryover()
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
            // `/logs` isn't idempotent, so only retry failures that mean the request never
            // reached the server — codes like `.timedOut` or `.networkConnectionLost` are
            // ambiguous about whether the server already processed the POST, and retrying those
            // risks writing the same log twice.
            switch (error as? URLError)?.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
    }

    func loadLogs(on date: Date) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            logs = try await fetchLogs(on: date)
            isCarryoverSession = false
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    /// Loads today's KST session, same as `loadLogs(on: Date())`, but with one fallback: a
    /// session is labeled by the KST date of the 기상 log that opened it (see the KST session
    /// model in docs/api-contract.md), so a user who wakes up, never logs 취침, and reopens the
    /// app after KST midnight would otherwise see an empty "오늘" — their session is still open,
    /// it's just filed under yesterday's date. When today's own fetch has no 기상 at all, this
    /// checks yesterday for a still-open session and shows that instead, so the quick-log buttons
    /// and metric cards reflect the session actually in progress rather than looking like nothing
    /// was ever logged.
    func loadTodayIncludingCarryover() async {
        await loadLogs(on: Date())
        guard errorMessage == nil, !logs.contains(where: { $0.type == .wake }) else { return }
        var kstCalendar = Calendar(identifier: .gregorian)
        kstCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        guard let yesterday = kstCalendar.date(byAdding: .day, value: -1, to: Date()) else { return }

        // A failure here shouldn't surface as an error or override today's (empty but valid)
        // state — today's own load already succeeded, this is just a best-effort extra check.
        guard let yesterdayLogs = try? await fetchLogs(on: yesterday),
              computeRoutineDayMetrics(from: yesterdayLogs).wakeOpenSince != nil else { return }

        logs = yesterdayLogs
        isCarryoverSession = true
    }

    private func fetchLogs(on date: Date) async throws -> [LogEntry] {
        let dateKey = Self.dateKeyFormatter.string(from: date)
        return try await client.functions.invoke(
            "logs",
            options: .init(method: .get, query: [URLQueryItem(name: "date", value: dateKey)])
        )
    }
}
