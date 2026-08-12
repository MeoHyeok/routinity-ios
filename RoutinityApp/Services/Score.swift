//
//  Score.swift
//  RoutinityApp
//

import Foundation

struct Score: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let scoreDate: String
    let score: Int
    let wakeScore: Int?
    let studyScore: Int?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scoreDate = "score_date"
        case score
        case wakeScore = "wake_score"
        case studyScore = "study_score"
        case updatedAt = "updated_at"
    }
}

struct ScoreUpsert: Encodable {
    let userId: UUID
    let scoreDate: String
    let score: Int
    let wakeScore: Int?
    let studyScore: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case scoreDate = "score_date"
        case score
        case wakeScore = "wake_score"
        case studyScore = "study_score"
    }
}
