//
//  TimeBreakdownChart.swift
//  RoutinityApp
//

import Charts
import SwiftUI

/// Donut chart of 식사/공부/휴식 within the day's 기상~취침 window, shared by the AI 코치 tab's
/// report screen and the sheet shown right after logging 취침.
struct TimeBreakdownChart: View {
    let breakdown: TimeBreakdown

    private var segments: [(label: String, minutes: Int, color: Color)] {
        [
            ("식사", breakdown.mealMinutes, .routinityPink),
            ("공부", breakdown.studyMinutes, .routinityCyan),
            ("휴식", breakdown.restMinutes, .routinityViolet),
        ]
    }

    /// A same-instant 기상~취침 (or any day where every bucket is genuinely 0) leaves nothing for
    /// SectorMark to draw — an all-zero-angle chart renders as an empty area, which reads as a
    /// broken chart rather than "there's just no data yet." Falls back to a plain track ring.
    private var hasAnyData: Bool {
        segments.contains { $0.minutes > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("24시간 시간 분배")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                Group {
                    if hasAnyData {
                        Chart(segments, id: \.label) { segment in
                            SectorMark(
                                angle: .value("분", max(segment.minutes, 0)),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.5
                            )
                            .foregroundStyle(segment.color)
                            .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 14)
                            .padding(6)
                    }
                }
                .frame(width: 132, height: 132)
                .overlay {
                    VStack(spacing: 0) {
                        Text(Self.formatDuration(breakdown.activeMinutes))
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("활동 시간")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments, id: \.label) { segment in
                        HStack(spacing: 8) {
                            Circle().fill(segment.color).frame(width: 8, height: 8)
                            Text(segment.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Self.formatDuration(segment.minutes))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .routinityCard()
    }

    private static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, let m): return "\(m)분"
        case (let h, 0): return "\(h)시간"
        default: return "\(hours)시간 \(remainder)분"
        }
    }
}
