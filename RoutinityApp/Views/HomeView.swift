//
//  HomeView.swift
//  RoutinityApp
//

import Auth
import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var logsViewModel = LogsViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var userId: UUID? { authViewModel.session?.user.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                        Button {
                            guard let userId else { return }
                            Task { await logsViewModel.recordLog(type: type, userId: userId) }
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

                if let userId {
                    NavigationLink("오늘 타임라인 보기") {
                        TimelineView(userId: userId)
                    }

                    NavigationLink("목표 설정") {
                        GoalsView(userId: userId)
                    }

                    NavigationLink("오늘 점수") {
                        ScoreView(userId: userId)
                    }
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
