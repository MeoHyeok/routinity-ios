//
//  LogEntry.swift
//  RoutinityApp
//

import Foundation

struct LogEntry: Identifiable, Codable, Hashable {
    enum LogType: String, Codable, CaseIterable {
        case wake
        case meal
        case studyStart = "study_start"
        case studyEnd = "study_end"

        var displayName: String {
            switch self {
            case .wake: return "기상"
            case .meal: return "식사"
            case .studyStart: return "공부 시작"
            case .studyEnd: return "공부 종료"
            }
        }

        var symbolName: String {
            switch self {
            case .wake: return "sun.max"
            case .meal: return "fork.knife"
            case .studyStart: return "book"
            case .studyEnd: return "checkmark.circle"
            }
        }
    }

    let id: UUID
    let type: LogType
    let timestamp: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case timestamp
        case createdAt = "created_at"
    }
}

struct NewLogRequest: Encodable {
    let type: String
    let timestamp: String
}
