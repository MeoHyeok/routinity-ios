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

struct TimeBreakdown: Decodable {
    let activeMinutes: Int
    let mealMinutes: Int
    let studyMinutes: Int
    let restMinutes: Int

    enum CodingKeys: String, CodingKey {
        case activeMinutes = "active_minutes"
        case mealMinutes = "meal_minutes"
        case studyMinutes = "study_minutes"
        case restMinutes = "rest_minutes"
    }
}

struct Report: Decodable {
    let period: String
    let date: String?
    let dateRange: DateRange?
    let content: String
    let cached: Bool
    let generatedVia: String?
    let timeBreakdown: TimeBreakdown?
    /// A single concrete next step targeting the user's biggest current loss, e.g. "공부 시간이
    /// 목표보다 30분 부족했어요. 내일은...". nil when there's nothing to flag (no scorable goal,
    /// or everything's already achieved) — same convention as timeBreakdown being nil.
    let suggestedAction: String?

    enum CodingKeys: String, CodingKey {
        case period
        case date
        case dateRange = "date_range"
        case content
        case cached
        case generatedVia = "generated_via"
        case timeBreakdown = "time_breakdown"
        case suggestedAction = "suggested_action"
    }
}
