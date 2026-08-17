//
//  LogEntry.swift
//  RoutinityApp
//

import Foundation

struct LogEntry: Identifiable, Codable, Hashable {
    enum LogType: String, Codable, CaseIterable {
        case wake
        case sleep
        case mealStart = "meal_start"
        case mealEnd = "meal_end"
        case studyStart = "study_start"
        case studyEnd = "study_end"

        var displayName: String {
            switch self {
            case .wake: return "기상"
            case .sleep: return "취침"
            case .mealStart: return "식사 시작"
            case .mealEnd: return "식사 종료"
            case .studyStart: return "공부 시작"
            case .studyEnd: return "공부 종료"
            }
        }

        var symbolName: String {
            switch self {
            case .wake: return "sun.max"
            case .sleep: return "moon.stars"
            case .mealStart: return "fork.knife"
            case .mealEnd: return "checkmark.circle"
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
