//
//  Theme.swift
//  RoutinityApp
//
//  Shared visual tokens so the minimal look (flat cards, one accent
//  color, generous spacing) stays consistent across screens.
//

import SwiftUI
import UIKit

extension Color {
    static let routinityCard = Color(uiColor: .secondarySystemBackground)
    static let routinityBackground = Color(uiColor: .systemBackground)
}

enum RoutinityMetrics {
    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 14
}

extension View {
    /// Flat, non-blurred card surface — deliberately not `.thinMaterial`, which reads as
    /// "glassy" rather than the plain minimal look this app is going for.
    func routinityCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.cardCornerRadius, style: .continuous))
    }

    func routinityFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.controlCornerRadius, style: .continuous))
    }
}
