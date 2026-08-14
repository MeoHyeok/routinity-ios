//
//  Insights.swift
//  RoutinityApp
//

import Foundation

struct Insights: Decodable {
    struct WeekdayAverage: Decodable, Identifiable {
        let weekday: Int
        let label: String
        let avgDailyScore: Int
        let daysCounted: Int

        var id: Int { weekday }

        enum CodingKeys: String, CodingKey {
            case weekday
            case label
            case avgDailyScore = "avg_daily_score"
            case daysCounted = "days_counted"
        }
    }

    struct WeekdaySummary: Decodable {
        let weekday: Int
        let label: String
        let avgDailyScore: Int

        enum CodingKeys: String, CodingKey {
            case weekday
            case label
            case avgDailyScore = "avg_daily_score"
        }
    }

    struct Trend: Decodable {
        let direction: String
        let recentAvg: Int
        let previousAvg: Int

        enum CodingKeys: String, CodingKey {
            case direction
            case recentAvg = "recent_avg"
            case previousAvg = "previous_avg"
        }
    }

    let dateRange: DateRange
    let weekdayAverages: [WeekdayAverage]
    let bestWeekday: WeekdaySummary?
    let worstWeekday: WeekdaySummary?
    let trend: Trend?

    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case weekdayAverages = "weekday_averages"
        case bestWeekday = "best_weekday"
        case worstWeekday = "worst_weekday"
        case trend
    }
}
