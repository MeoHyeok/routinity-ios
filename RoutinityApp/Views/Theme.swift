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
    // Dark, glowing dashboard look: near-black backdrop, slightly-raised card surfaces, a
    // violet→pink→cyan gradient family used consistently for emphasis (rings, headlines,
    // active states) rather than scattering many hues.
    static let routinityBackground = Color(red: 0.043, green: 0.043, blue: 0.067)
    static let routinityCard = Color(red: 0.086, green: 0.086, blue: 0.122)
    static let routinityCardBorder = Color.white.opacity(0.06)
    static let routinityGlow = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.28)

    static let routinityViolet = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let routinityPink = Color(red: 0.93, green: 0.38, blue: 0.62)
    static let routinityCyan = Color(red: 0.30, green: 0.78, blue: 0.93)
    static let routinityOrange = Color(red: 0.98, green: 0.58, blue: 0.29)
    static let routinityGreen = Color(red: 0.35, green: 0.82, blue: 0.55)
}

extension LinearGradient {
    static let routinityAccent = LinearGradient(
        colors: [.routinityViolet, .routinityPink],
        startPoint: .leading, endPoint: .trailing
    )
    static let routinityHeadline = LinearGradient(
        colors: [.routinityPink, .routinityViolet],
        startPoint: .leading, endPoint: .trailing
    )
}

enum RoutinityMetrics {
    static let cardCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 14
}

extension View {
    /// Card surface for the dark dashboard: subtle raised fill, hairline border, soft glow
    /// instead of a hard drop shadow (a real shadow reads oddly on a near-black backdrop).
    func routinityCard(padding: CGFloat = 16, glow: Bool = false) -> some View {
        self
            .padding(padding)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RoutinityMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(glow ? Color.routinityViolet.opacity(0.35) : Color.routinityCardBorder, lineWidth: 1)
            )
            .shadow(color: glow ? Color.routinityGlow : .clear, radius: 20, x: 0, y: 8)
    }

    func routinityFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.routinityCard, in: RoundedRectangle(cornerRadius: RoutinityMetrics.controlCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RoutinityMetrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(Color.routinityCardBorder, lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}
