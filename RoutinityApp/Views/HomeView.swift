//
//  HomeView.swift
//  RoutinityApp
//

import SwiftUI

private struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let symbolName: String
}

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var logsViewModel = LogsViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private let menuItems: [(item: MenuItem, destination: AnyView)] = [
        (MenuItem(title: "오늘 타임라인 보기", symbolName: "clock"), AnyView(TimelineView())),
        (MenuItem(title: "목표 설정", symbolName: "target"), AnyView(GoalsView())),
        (MenuItem(title: "오늘 점수", symbolName: "gauge.with.dots.needle.67percent"), AnyView(ScoreView())),
        (MenuItem(title: "오늘 리포트", symbolName: "doc.text"), AnyView(ReportView(period: .daily))),
        (MenuItem(title: "주간 리포트", symbolName: "calendar"), AnyView(ReportView(period: .weekly))),
        (MenuItem(title: "월간 리포트", symbolName: "calendar.badge.clock"), AnyView(ReportView(period: .monthly))),
        (MenuItem(title: "패턴 분석", symbolName: "chart.bar"), AnyView(InsightsView())),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                            Button {
                                Task { await logsViewModel.recordLog(type: type) }
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.12))
                                            .frame(width: 52, height: 52)
                                        if logsViewModel.isRecording == type {
                                            ProgressView()
                                        } else {
                                            Image(systemName: type.symbolName)
                                                .font(.title2)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    Text(type.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            }
                            .routinityCard(padding: 0)
                            .disabled(logsViewModel.isRecording != nil)
                        }
                    }

                    if let errorMessage = logsViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    VStack(spacing: 2) {
                        ForEach(menuItems, id: \.item.id) { entry in
                            NavigationLink {
                                entry.destination
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: entry.item.symbolName)
                                        .font(.body)
                                        .foregroundStyle(.tint)
                                        .frame(width: 24)
                                    Text(entry.item.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .routinityCard(padding: 4)

                    Button("로그아웃") {
                        Task { await authViewModel.signOut() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .navigationTitle("루티니티")
        }
    }
}

#Preview {
    HomeView(authViewModel: AuthViewModel())
}
