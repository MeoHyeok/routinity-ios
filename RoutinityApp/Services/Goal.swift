//
//  Goal.swift
//  RoutinityApp
//

import Foundation

struct Goal: Identifiable, Codable, Hashable {
    enum TargetType: String, Codable, CaseIterable {
        case wake
        case studyMinutes = "study_minutes"

        var displayName: String {
            switch self {
            case .wake: return "기상 목표"
            case .studyMinutes: return "공부 시간 목표"
            }
        }
    }

    let id: UUID
    let userId: UUID
    let targetType: TargetType
    let targetValue: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case targetType = "target_type"
        case targetValue = "target_value"
        case updatedAt = "updated_at"
    }
}

struct NewGoal: Encodable {
    let userId: UUID
    let targetType: String
    let targetValue: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case targetType = "target_type"
        case targetValue = "target_value"
    }
}

struct GoalUpdate: Encodable {
    let targetValue: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case targetValue = "target_value"
        case updatedAt = "updated_at"
    }
}
