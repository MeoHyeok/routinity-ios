//
//  NetworkLogger.swift
//  RoutinityApp
//

import Foundation
import os

/// Structured request logging around every `client.functions.invoke` call, so a request that
/// actually left the device can be told apart from one that failed before ever reaching the
/// network (both would otherwise just look like "nothing happened" from the user's side). Each
/// call logs the moment it starts (proof the request was sent) and the moment it finishes
/// (success, or the specific error) — timestamps in the device console can then be lined up
/// against the backend's own structured request logs to confirm whether a given tap's request
/// ever arrived server-side.
enum NetworkLogger {
    private static let logger = Logger(subsystem: "com.meohyeok.RoutinityApp", category: "network")

    static func requestStarted(_ label: String) {
        logger.notice("→ \(label, privacy: .public) sending")
    }

    static func requestSucceeded(_ label: String) {
        logger.notice("← \(label, privacy: .public) succeeded")
    }

    static func requestFailed(_ label: String, _ error: Error) {
        logger.error("✗ \(label, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }
}

func loggedInvoke<T>(_ label: String, _ call: () async throws -> T) async throws -> T {
    NetworkLogger.requestStarted(label)
    do {
        let result = try await call()
        NetworkLogger.requestSucceeded(label)
        return result
    } catch {
        NetworkLogger.requestFailed(label, error)
        throw error
    }
}

func loggedInvoke(_ label: String, _ call: () async throws -> Void) async throws {
    NetworkLogger.requestStarted(label)
    do {
        try await call()
        NetworkLogger.requestSucceeded(label)
    } catch {
        NetworkLogger.requestFailed(label, error)
        throw error
    }
}
