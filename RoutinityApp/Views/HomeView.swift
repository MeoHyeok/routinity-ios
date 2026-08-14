//
//  HomeView.swift
//  RoutinityApp
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var logsViewModel = LogsViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                        Button {
                            Task { await logsViewModel.recordLog(type: type) }
                        } label: {
                            VStack(spacing: 8) {
                                if logsViewModel.isRecording == type {
                                    ProgressView()
                                } else {
                                    Image(systemName: type.symbolName)
                                        .font(.title)
                                }
                                Text(type.displayName)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        .buttonStyle(.bordered)
                        .disabled(logsViewModel.isRecording != nil)
                    }
                }

                if let errorMessage = logsViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                NavigationLink("오늘 타임라인 보기") {
                    TimelineView()
                }

                NavigationLink("목표 설정") {
                    GoalsView()
                }

                NavigationLink("오늘 점수") {
                    ScoreView()
                }

                NavigationLink("오늘 리포트") {
                    ReportView(period: .daily)
                }

                NavigationLink("주간 리포트") {
                    ReportView(period: .weekly)
                }

                Spacer()

                Button("로그아웃") {
                    Task { await authViewModel.signOut() }
                }
            }
            .padding()
            .navigationTitle("루티니티")
        }
    }
}

#Preview {
    HomeView(authViewModel: AuthViewModel())
}
