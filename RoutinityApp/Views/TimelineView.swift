//
//  TimelineView.swift
//  RoutinityApp
//

import SwiftUI

struct TimelineView: View {
    @StateObject private var logsViewModel = LogsViewModel()
    @State private var selectedDate = Date()

    /// `DatePicker` hands back a `Date` anchored to whatever calendar day it displayed, using the
    /// *device's* timezone — reformatting that instant through a KST-pinned formatter (as
    /// `loadLogs` does) can land on a different calendar date whenever the device's UTC offset is
    /// ahead of KST's (+9): e.g. local midnight of a picked day in a UTC+13 zone is still the
    /// previous day in KST. Re-anchoring to noon KST of the same Y/M/D the picker displayed keeps
    /// the queried date matching what's on screen regardless of device timezone.
    private func kstAnchoredDate(from date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var kstCalendar = Calendar(identifier: .gregorian)
        kstCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return kstCalendar.date(from: DateComponents(year: components.year, month: components.month, day: components.day, hour: 12)) ?? date
    }

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
                // The API doesn't guarantee response order (TodayView's own log-pairing logic
                // sorts before relying on it too), so without this a "타임라인" could render out
                // of chronological order.
                List(logsViewModel.logs.sorted(by: { $0.timestamp < $1.timestamp })) { log in
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
            await logsViewModel.loadLogs(on: kstAnchoredDate(from: selectedDate))
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
