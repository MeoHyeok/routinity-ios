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
    // White cards floating on a soft gray backdrop (the Settings/Health pattern) read as far
    // more "finished" than gray-card-on-white once a shadow is added — flat same-tone fills are
    // what made the first pass feel unstyled.
    static let routinityCard = Color(uiColor: .systemBackground)
    static let routinityBackground = Color(uiColor: .systemGroupedBackground)
    static let routinityShadow = Color.black.opacity(0.08)
}

enum RoutinityMetrics {
    static let cardCornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 14
}

extension View {
    /// Card surface with a soft, single-light-source shadow for depth.
    func routinityCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.cardCornerRadius, style: .continuous))
            .shadow(color: Color.routinityShadow, radius: 12, x: 0, y: 4)
    }

    func routinityFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.controlCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RoutinityMetrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
