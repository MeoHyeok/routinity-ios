//
//  Report.swift
//  RoutinityApp
//

import Foundation

struct DateRange: Decodable {
    let from: String
    let to: String
}

enum ReportPeriod {
    case daily
    case weekly
    case monthly

    var functionName: String {
        switch self {
        case .daily: return "reports-daily"
        case .weekly: return "reports-weekly"
        case .monthly: return "reports-monthly"
        }
    }

    var navigationTitle: String {
        switch self {
        case .daily: return "오늘 리포트"
        case .weekly: return "주간 리포트"
        case .monthly: return "월간 리포트"
        }
    }
}

struct Report: Decodable {
    let period: String
    let date: String?
    let dateRange: DateRange?
    let content: String
    let cached: Bool
    let generatedVia: String?

    enum CodingKeys: String, CodingKey {
        case period
        case date
        case dateRange = "date_range"
        case content
        case cached
        case generatedVia = "generated_via"
    }
}
