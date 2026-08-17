//
//  TimelineView.swift
//  RoutinityApp
//

import SwiftUI

struct TimelineView: View {
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
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("이 날짜에는 기록이 없습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(logsViewModel.logs) { log in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: log.type.symbolName)
                                .font(.footnote)
                                .foregroundStyle(.tint)
                        }
                        Text(log.type.displayName)
                        Spacer()
                        Text(log.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button("삭제", role: .destructive) {
                            Task { await logsViewModel.deleteLog(id: log.id) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("타임라인")
        .background(Color.routinityBackground)
        .task(id: selectedDate) {
            await logsViewModel.loadLogs(on: selectedDate)
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
