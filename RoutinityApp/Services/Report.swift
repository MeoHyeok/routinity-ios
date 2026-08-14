//
//  Report.swift
//  RoutinityApp
//

import Foundation

enum ReportPeriod {
    case daily
    case weekly

    var functionName: String {
        switch self {
        case .daily: return "reports-daily"
        case .weekly: return "reports-weekly"
        }
    }

    var navigationTitle: String {
        switch self {
        case .daily: return "오늘 리포트"
        case .weekly: return "주간 리포트"
        }
    }
}

struct Report: Decodable {
    let period: String
    let date: String?
    let content: String
    let cached: Bool
    let generatedVia: String?

    enum CodingKeys: String, CodingKey {
        case period
        case date
        case content
        case cached
        case generatedVia = "generated_via"
    }
}
