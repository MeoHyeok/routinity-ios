//
//  AnalysisView.swift
//  RoutinityApp
//

import Charts
import SwiftUI

struct AnalysisView: View {
    private enum Window: String, CaseIterable, Identifiable {
        case weekly = "주간"
        case monthly = "월간"
        var id: String { rawValue }
        var days: Int { self == .weekly ? 7 : 30 }
    }

    @StateObject private var trendViewModel = TrendViewModel()
    @StateObject private var insightsViewModel = InsightsViewModel()
    @State private var window: Window = .weekly

    /// Points with a nil dailyScore don't get a mark drawn, so without an explicit domain the
    /// chart's x-axis silently shrinks to whichever days happen to have a score — the requested
    /// week/month should always show in full, missing days included, so it stays comparable
    /// week to week.
    private var chartDateDomain: ClosedRange<Date> {
        guard let first = trendViewModel.points.first?.date, let last = trendViewModel.points.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }

    private var averageScore: Int? {
        let scored = trendViewModel.points.compactMap { $0.dailyScore }
        guard !scored.isEmpty else { return nil }
        return Int((Double(scored.reduce(0, +)) / Double(scored.count)).rounded())
    }

    /// Shared with AICoachView so a report reader gets the same suggestion + 목표 설정 path
    /// without having to separately visit 분석.
    private var goalSuggestion: GoalSuggestion? {
        computeGoalSuggestion(from: trendViewModel.points)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Picker("기간", selection: $window) {
                        ForEach(Window.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)

                    if trendViewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        summaryCard
                        trendChartCard
                        studyBarChartCard
                        bestWorstWeekdayRow
                        lossAnalysisCard
                        goalSuggestionCard
                    }

                    if let errorMessage = trendViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: window) {
                await trendViewModel.loadTrend(days: window.days)
            }
            .task {
                await insightsViewModel.loadInsights()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("루틴 분석")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient.routinityHeadline)
            Text("기록을 바탕으로 패턴을 확인해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(window.rawValue) 평균")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(averageScore.map { "\($0)" } ?? "-")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient.routinityAccent)
                }
                Spacer()
                if let trend = insightsViewModel.insights?.trend {
                    trendBadge(trend)
                }
            }

            VStack(spacing: 10) {
                progressRow(title: "루틴 준수", value: averageScore ?? 0, color: .routinityViolet)
                progressRow(title: "기상 규칙성", value: consistency(for: GoalTargetType.wakeTime), color: .routinityOrange)
                progressRow(title: "공부 목표 달성도", value: consistency(for: GoalTargetType.studyDuration), color: .routinityCyan)
            }
        }
        .routinityCard(glow: true)
    }

    private func consistency(for targetType: String) -> Int {
        guard let missRate = trendViewModel.missRate(for: targetType) else { return 0 }
        return Int(((1 - missRate) * 100).rounded())
    }

    /// Surfaces the recent-vs-previous-7-day delta explicitly (not just a direction arrow) so a
    /// glance answers "better or worse than before, and by how much" — the raw numbers already
    /// come back from /insights, this just stops burying the comparison behind the average alone.
    private func trendBadge(_ trend: Insights.Trend) -> some View {
        let delta = trend.recentAvg - trend.previousAvg
        let symbol = trend.direction == "up" ? "arrow.up.right" : (trend.direction == "down" ? "arrow.down.right" : "arrow.right")
        let color: Color = trend.direction == "up" ? .routinityGreen : (trend.direction == "down" ? .routinityPink : .secondary)
        let deltaText = delta == 0 ? "지난 7일과 동일" : "지난 7일 대비 \(delta > 0 ? "+" : "")\(delta)점"
        return VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text("최근 7일 \(trend.recentAvg)점")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            Text(deltaText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func progressRow(title: String, value: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(value, 100))) / 100)
                }
            }
            .frame(height: 6)
            Text("\(value)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("루틴 점수 추이")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(trendViewModel.points) { point in
                if let score = point.dailyScore {
                    AreaMark(x: .value("날짜", point.date), y: .value("점수", score))
                        .foregroundStyle(LinearGradient(colors: [.routinityViolet.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("날짜", point.date), y: .value("점수", score))
                        .foregroundStyle(Color.routinityViolet)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("날짜", point.date), y: .value("점수", score))
                        .foregroundStyle(Color.routinityViolet)
                        .symbolSize(24)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: chartDateDomain)
            .chartXAxis {
                AxisMarks(values: window == .weekly ? .stride(by: .day) : .stride(by: .day, count: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(TrendViewModel.weekdayLabel(for: date))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
        }
        .routinityCard()
    }

    private var studyBarChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("공부 시간 — 실제 vs 목표 (분)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(trendViewModel.points) { point in
                if let entry = point.entry(for: GoalTargetType.studyDuration), let actual = Int(entry.actualValue ?? "") {
                    BarMark(x: .value("날짜", point.date), y: .value("실제", actual), width: .fixed(8))
                        .foregroundStyle(Color.routinityCyan)
                        .position(by: .value("구분", "실제"))
                }
                if let entry = point.entry(for: GoalTargetType.studyDuration), let target = Int(entry.targetValue) {
                    BarMark(x: .value("날짜", point.date), y: .value("목표", target), width: .fixed(8))
                        .foregroundStyle(Color.white.opacity(0.18))
                        .position(by: .value("구분", "목표"))
                }
            }
            .chartXScale(domain: chartDateDomain)
            .chartXAxis {
                AxisMarks(values: window == .weekly ? .stride(by: .day) : .stride(by: .day, count: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(TrendViewModel.weekdayLabel(for: date))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)

            HStack(spacing: 16) {
                legendDot(color: .routinityCyan, label: "실제")
                legendDot(color: Color.white.opacity(0.18), label: "목표")
            }
        }
        .routinityCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var bestWorstWeekdayRow: some View {
        if let insights = insightsViewModel.insights,
           insights.weekdayAverages.count > 1,
           let best = insights.bestWeekday, let worst = insights.worstWeekday {
            HStack(spacing: 12) {
                weekdaySummaryCard(title: "가장 좋은 요일", summary: best, color: .routinityGreen)
                weekdaySummaryCard(title: "가장 아쉬운 요일", summary: worst, color: .routinityPink)
            }
        }
    }

    private func weekdaySummaryCard(title: String, summary: Insights.WeekdaySummary, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(summary.label).font(.title3.bold()).foregroundStyle(.white)
            Text("\(summary.avgDailyScore)점").font(.caption.weight(.semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinityCard(padding: 12)
    }

    private var lossAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("루틴 로스 분석")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            lossRow(title: "기상 지연", rate: trendViewModel.missRate(for: GoalTargetType.wakeTime), color: .routinityPink)
            lossRow(title: "공부 시작 지연", rate: trendViewModel.missRate(for: GoalTargetType.studyDuration), color: .routinityOrange)
            lossRow(title: "식사 불규칙", rate: trendViewModel.mealIrregularityRate, color: .routinityViolet)
        }
        .routinityCard()
    }

    @ViewBuilder
    private func lossRow(title: String, rate: Double?, color: Color) -> some View {
        if let rate {
            let percent = Int((rate * 100).rounded())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.subheadline).foregroundStyle(.white)
                    Spacer()
                    Text("\(percent)%").font(.subheadline.weight(.bold)).foregroundStyle(color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(color).frame(width: geo.size.width * CGFloat(percent) / 100)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    @ViewBuilder
    private var goalSuggestionCard: some View {
        if let suggestion = goalSuggestion {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.routinityOrange)
                    Text("목표 제안")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Text("\(suggestion.lossTitle)이 최근 \(Int((suggestion.missRate * 100).rounded()))%로 잦아요. 최근 실제 평균에 맞춰 목표를 \(suggestion.suggestedLabel)로 조정해보는 건 어떨까요?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    GoalsView(suggestedWakeTime: suggestion.suggestedWakeTime, suggestedStudyMinutes: suggestion.suggestedStudyMinutes)
                } label: {
                    Text("목표 조정하러 가기")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.routinityViolet)
                }
            }
            .routinityCard(glow: true)
        }
    }
}

#Preview {
    AnalysisView()
}
