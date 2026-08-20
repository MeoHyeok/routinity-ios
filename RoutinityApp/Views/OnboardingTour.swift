//
//  OnboardingTour.swift
//  RoutinityApp
//

import SwiftUI

/// Collects the on-screen frame of every view tagged `.tourAnchor(_:)`, keyed by that id, so
/// `SpotlightOverlay` can cut a hole around whichever one the current tour step targets. Not
/// private: `.overlayPreferenceValue(TourAnchorKey.self)` has to be attached to the ancestor view
/// that actually contains the tagged elements (TodayView's NavigationStack) for the preference to
/// bubble up to it at all — reading it from a disconnected sibling view's own subtree, as an
/// earlier version of this file did, always sees an empty dictionary.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as a possible spotlight target for the onboarding tour.
    func tourAnchor(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

struct TourStep {
    /// Matches a `.tourAnchor(_:)` id to spotlight, or nil for a plain centered card (used for
    /// the closing step, which doesn't point at anything specific).
    let anchorID: String?
    let title: String
    let message: String
    /// True only for the one step where we want the user to actually perform the action rather
    /// than just read about it — everything else advances on "다음" alone.
    let advancesOnRealAction: Bool

    static let steps: [TourStep] = [
        TourStep(
            anchorID: "score",
            title: "오늘의 루틴 점수",
            message: "목표 대비 오늘 얼마나 지켰는지 여기서 한눈에 확인할 수 있어요.",
            advancesOnRealAction: false
        ),
        TourStep(
            anchorID: "wakeButton",
            title: "지금 기상하셨나요?",
            message: "이 버튼을 눌러서 첫 기록을 남겨보세요. 다시 누르면 취침으로 바뀌어요.",
            advancesOnRealAction: true
        ),
        TourStep(
            anchorID: "settingsButton",
            title: "목표와 알림 설정",
            message: "기상 08:00 · 공부 5시간으로 기본 목표를 설정해드렸어요. 여기서 언제든 바꾸고, 기록 알림도 켤 수 있어요.",
            advancesOnRealAction: false
        ),
        TourStep(
            anchorID: nil,
            title: "분석과 AI 코치도 둘러보세요",
            message: "하단 탭의 '분석'에서는 루틴 트렌드를, 'AI 코치'에서는 하루·주간 리포트를 확인할 수 있어요.",
            advancesOnRealAction: false
        ),
    ]
}

/// Full-screen dark overlay with a cutout around the current step's target (via a
/// destinationOut-blended shape), plus a callout card near it explaining what it does.
///
/// Takes the already-resolved target rect and screen size as plain parameters rather than
/// reading `TourAnchorKey` itself — anchor preferences only bubble up to an ancestor of the
/// tagged views, so the reader has to be attached where TodayView's NavigationStack lives (see
/// `.tourOverlay(...)` below), not inside this view's own disconnected body.
struct SpotlightOverlay: View {
    let steps: [TourStep]
    @Binding var stepIndex: Int
    let targetRect: CGRect?
    let screenSize: CGSize
    let isRealActionSatisfied: Bool
    let onFinish: () -> Void

    var body: some View {
        let step = steps[stepIndex]

        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
            if let targetRect {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .frame(width: targetRect.width + 14, height: targetRect.height + 14)
                    .position(x: targetRect.midX, y: targetRect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .allowsHitTesting(!step.advancesOnRealAction) // let taps reach the real button underneath
        .overlay {
            calloutCard(for: step, targetRect: targetRect, in: screenSize)
        }
        .onChange(of: isRealActionSatisfied) { _, satisfied in
            guard satisfied, steps[stepIndex].advancesOnRealAction else { return }
            advance()
        }
    }

    /// Placed via a full-screen frame + top/bottom padding (an explicit gap from the target's
    /// edge) rather than `.position()` at a computed center point — `.position()` needs the
    /// card's own height to know where its edge actually lands, which isn't known ahead of the
    /// text laying out, so a fixed center offset risks the card overlapping the very thing it's
    /// pointing at. Padding from the correct edge stays correct regardless of the card's height.
    private func calloutCard(for step: TourStep, targetRect: CGRect?, in screenSize: CGSize) -> some View {
        let midY = targetRect?.midY ?? screenSize.height / 2
        let calloutBelow = midY < screenSize.height * 0.55
        let gap: CGFloat = 24

        let card = VStack(alignment: .leading, spacing: 12) {
            progressDots
            Text(step.title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            calloutFooter(for: step)
        }
        .padding(18)
        .routinityCard(glow: true)
        .frame(maxWidth: 340)

        return Group {
            if calloutBelow {
                card.padding(.top, (targetRect?.maxY ?? 0) + gap)
            } else {
                card.padding(.bottom, screenSize.height - (targetRect?.minY ?? screenSize.height) + gap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: calloutBelow ? .top : .bottom)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                let isCurrent = index == stepIndex
                Capsule()
                    .fill(isCurrent ? Color.routinityViolet : Color.white.opacity(0.2))
                    .frame(width: isCurrent ? 18 : 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private func calloutFooter(for step: TourStep) -> some View {
        HStack {
            Button("건너뛰기", action: onFinish)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if step.advancesOnRealAction {
                if !isRealActionSatisfied {
                    Text("버튼을 눌러보세요 →")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.routinityCyan)
                }
            } else {
                let label = stepIndex == steps.count - 1 ? "시작하기" : "다음"
                Button(label, action: advance)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.routinityViolet)
            }
        }
    }

    private func advance() {
        if stepIndex < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { stepIndex += 1 }
        } else {
            onFinish()
        }
    }
}

extension View {
    /// Call on (or above) the view tree that contains the `.tourAnchor(_:)`-tagged elements —
    /// `TourAnchorKey`'s values only bubble up to an ancestor, so this can't be attached anywhere
    /// else and still see them.
    func tourOverlay(
        isActive: Bool,
        stepIndex: Binding<Int>,
        isRealActionSatisfied: Bool,
        onFinish: @escaping () -> Void
    ) -> some View {
        overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if isActive {
                    let step = TourStep.steps[stepIndex.wrappedValue]
                    let targetRect = step.anchorID.flatMap { anchors[$0] }.map { proxy[$0] }
                    SpotlightOverlay(
                        steps: TourStep.steps,
                        stepIndex: stepIndex,
                        targetRect: targetRect,
                        screenSize: proxy.size,
                        isRealActionSatisfied: isRealActionSatisfied,
                        onFinish: onFinish
                    )
                }
            }
        }
    }
}
