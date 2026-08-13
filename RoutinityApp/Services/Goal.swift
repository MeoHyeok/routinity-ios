//
//  Goal.swift
//  RoutinityApp
//

import Foundation

/// `target_type` is a free-form string per the API contract, not a fixed enum — the server
/// accepts arbitrary values, only `wakeTime`/`studyDuration` have scoring rules today.
enum GoalTargetType {
    static let wakeTime = "wake_time"
    static let studyDuration = "study_duration"
}

struct Goal: Identifiable, Codable, Hashable {
    let id: UUID
    let targetType: String
    let targetValue: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case targetType = "target_type"
        case targetValue = "target_value"
        case updatedAt = "updated_at"
    }
}

struct GoalUpsertRequest: Encodable {
    let targetType: String
    let targetValue: String

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetValue = "target_value"
    }
}
