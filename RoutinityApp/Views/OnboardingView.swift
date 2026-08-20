//
//  OnboardingView.swift
//  RoutinityApp
//

import SwiftUI

/// Shown once, the first time a user reaches the authenticated app (right after signup, or after
/// confirming their email and signing in for the first time) — a quick swipe-through of the core
/// loop before they land on a blank 오늘 화면 with no context for what the buttons do.
struct OnboardingView: View {
    let onFinish: () -> Void

    private struct Slide {
        let icon: String
        let tint: Color
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(
            icon: "sun.max.fill", tint: .routinityOrange,
            title: "원탭으로 루틴을 기록하세요",
            body: "기상, 식사, 공부 — 버튼 하나만 누르면 지금 이 순간이 기록돼요. 다시 누르면 종료돼요."
        ),
        Slide(
            icon: "target", tint: .routinityCyan,
            title: "목표를 세우면 점수가 매겨져요",
            body: "기상 시간과 공부 시간 목표를 설정하면, 오늘 얼마나 지켰는지 자동으로 채점해드려요."
        ),
        Slide(
            icon: "sparkles", tint: .routinityViolet,
            title: "AI 코치가 리포트를 써드려요",
            body: "하루·주간·월간 리포트와 다음 액션 제안까지, 기록만 하면 AI가 알아서 정리해드려요."
        ),
    ]

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(slides.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.routinityViolet : Color.white.opacity(0.15))
                        .frame(width: index == page ? 20 : 6, height: 6)
                }
            }
            .padding(.bottom, 28)
            .animation(.easeInOut(duration: 0.2), value: page)

            Button {
                if page < slides.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < slides.count - 1 ? "다음" : "시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

            if page < slides.count - 1 {
                Button("건너뛰기", action: onFinish)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
            } else {
                Color.clear.frame(height: 14 + 17) // keeps the "시작하기" button's position stable
            }
        }
        .padding(.bottom, 24)
        .background(Color.routinityBackground)
        .preferredColorScheme(.dark)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(slide.tint.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: slide.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(slide.tint)
            }
            VStack(spacing: 10) {
                Text(slide.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(slide.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
