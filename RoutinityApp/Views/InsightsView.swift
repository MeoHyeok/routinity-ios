//
//  InsightsView.swift
//  RoutinityApp
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let insights = viewModel.insights {
                    Text("\(insights.dateRange.from) ~ \(insights.dateRange.to)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let trend = insights.trend {
                        trendCard(trend)
                    }

                    if let best = insights.bestWeekday, let worst = insights.worstWeekday {
                        HStack(spacing: 12) {
                            weekdaySummaryCard(title: "가장 좋은 요일", summary: best, color: .green)
                            weekdaySummaryCard(title: "가장 아쉬운 요일", summary: worst, color: .red)
                        }
                    }

                    if insights.weekdayAverages.isEmpty {
                        Text("아직 요일별 통계를 낼 만큼 기록이 쌓이지 않았어요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(insights.weekdayAverages.sorted { $0.weekday < $1.weekday }) { average in
                                HStack {
                                    Text(average.label)
                                        .font(.headline)
                                        .frame(width: 32, alignment: .leading)
                                    Text("\(average.daysCounted)일 기록")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(average.avgDailyScore)점")
                                        .font(.headline)
                                }
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("패턴 분석")
        .task {
            await viewModel.loadInsights()
        }
    }

    private func trendCard(_ trend: Insights.Trend) -> some View {
        HStack {
            Image(systemName: Self.trendSymbol(trend.direction))
                .foregroundStyle(Self.trendColor(trend.direction))
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("최근 7일 평균 \(trend.recentAvg)점")
                    .font(.headline)
                Text("이전 7일 평균 \(trend.previousAvg)점")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func weekdaySummaryCard(title: String, summary: Insights.WeekdaySummary, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(summary.label)
                .font(.title2.bold())
            Text("\(summary.avgDailyScore)점")
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private static func trendSymbol(_ direction: String) -> String {
        switch direction {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private static func trendColor(_ direction: String) -> Color {
        switch direction {
        case "up": return .green
        case "down": return .red
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
