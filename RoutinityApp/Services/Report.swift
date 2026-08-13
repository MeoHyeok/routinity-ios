//
//  Report.swift
//  RoutinityApp
//

import Foundation

struct WeeklyReport: Decodable {
    let period: String
    let content: String
    let cached: Bool
    let generatedVia: String?

    enum CodingKeys: String, CodingKey {
        case period
        case content
        case cached
        case generatedVia = "generated_via"
    }
}
