//
//  SuggestedActionCard.swift
//  RoutinityApp
//

import SwiftUI

/// Highlights the report's single concrete next step separately from the free-text summary, so
/// the "so what do I do" punchline doesn't get buried in prose. Shared by the AI 코치 tab's report
/// screen and the sheet shown right after logging 취침.
struct SuggestedActionCard: View {
    let action: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.routinityOrange)
                Text("다음 액션 제안")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(action)
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .routinityCard(glow: true)
    }
}
