//
//  TimelineView.swift
//  RoutinityApp
//

import SwiftUI

struct TimelineView: View {
    let userId: UUID

    @StateObject private var logsViewModel = LogsViewModel()
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 16) {
            DatePicker("날짜", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal)

            if logsViewModel.isLoading {
                ProgressView()
                Spacer()
            } else if let errorMessage = logsViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                Spacer()
            } else if logsViewModel.logs.isEmpty {
                Text("이 날짜에는 기록이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(logsViewModel.logs) { log in
                    HStack {
                        Image(systemName: log.type.symbolName)
                        Text(log.type.displayName)
                        Spacer()
                        Text(log.loggedAt, style: .time)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("타임라인")
        .task(id: selectedDate) {
            await logsViewModel.loadLogs(on: selectedDate, userId: userId)
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView(userId: UUID())
    }
}
