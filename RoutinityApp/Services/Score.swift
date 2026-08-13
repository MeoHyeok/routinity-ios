//
//  Score.swift
//  RoutinityApp
//

import Foundation

struct ScoresResponse: Decodable {
    let date: String
    let scores: [ScoreEntry]
}

struct ScoreEntry: Identifiable, Decodable, Hashable {
    enum Status: String, Decodable {
        case achieved
        case notAchieved = "not_achieved"
        case missing
    }

    var id: String { targetType }
    let targetType: String
    let targetValue: String
    let actualValue: String?
    let status: Status

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetValue = "target_value"
        case actualValue = "actual_value"
        case status
    }
}
