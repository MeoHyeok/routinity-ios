//
//  NotificationManager.swift
//  RoutinityApp
//

import Foundation
import UserNotifications

/// Local (on-device) reminders that a day's wake/sleep log hasn't been recorded yet — there's no
/// push infrastructure (APNs, device token registration) on the backend, and these reminders are
/// inherently tied to the user's own goal times anyway, so local notifications are the right tool
/// rather than server-triggered push.
enum NotificationManager {
    static let wakeReminderID = "routinity.reminder.wake"
    static let sleepReminderID = "routinity.reminder.sleep"

    private static let defaultWakeHour = 8
    private static let defaultWakeMinute = 30
    private static let sleepReminderHour = 22
    private static let sleepReminderMinute = 0

    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [wakeReminderID, sleepReminderID]
        )
    }

    /// Re-derives just today's two reminders from the current logged state, replacing whatever
    /// was scheduled before. Single-fire (not repeating) and re-called on every data load / app
    /// foreground, so a reminder for something already logged never lingers — the cost is that
    /// tomorrow's reminder only gets scheduled once the app is actually opened again that day,
    /// since there's no background refresh to plan further ahead.
    static func scheduleTodayReminders(hasLoggedWake: Bool, hasLoggedSleep: Bool, wakeGoalTime: String?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [wakeReminderID, sleepReminderID])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        if !hasLoggedWake {
            let (hour, minute) = parseTime(wakeGoalTime) ?? (defaultWakeHour, defaultWakeMinute)
            if let trigger = todayTrigger(hour: hour, minute: minute, calendar: calendar) {
                schedule(
                    id: wakeReminderID,
                    title: "오늘 기상하셨나요?",
                    body: "루티니티에서 기상을 기록하고 하루를 시작해보세요.",
                    trigger: trigger, center: center
                )
            }
        }

        if hasLoggedWake && !hasLoggedSleep {
            if let trigger = todayTrigger(hour: sleepReminderHour, minute: sleepReminderMinute, calendar: calendar) {
                schedule(
                    id: sleepReminderID,
                    title: "오늘 하루 어떠셨나요?",
                    body: "취침을 기록하면 오늘의 리포트를 바로 받아볼 수 있어요.",
                    trigger: trigger, center: center
                )
            }
        }
    }

    private static func todayTrigger(hour: Int, minute: Int, calendar: Calendar) -> UNCalendarNotificationTrigger? {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        // Skip scheduling a reminder for a time that's already passed today rather than letting
        // it fire immediately/in the past.
        guard let fireDate = calendar.date(from: components), fireDate > Date() else { return nil }
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        return UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
    }

    private static func schedule(
        id: String, title: String, body: String, trigger: UNCalendarNotificationTrigger, center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func parseTime(_ value: String?) -> (hour: Int, minute: Int)? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return (hour, minute)
    }
}
