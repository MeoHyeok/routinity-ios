//
//  TodayView.swift
//  RoutinityApp
//

import Supabase
import SwiftUI
import UIKit

struct TodayView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var logsViewModel = LogsViewModel()
    @StateObject private var scoreViewModel = ScoreViewModel()
    @StateObject private var sleepReportViewModel = ReportViewModel()
    @StateObject private var streakViewModel = TrendViewModel()
    /// Not rendered anywhere — used purely to check/backfill goals for a brand-new account before
    /// the onboarding tour's first appearance (see `.task` below).
    @StateObject private var goalsViewModel = GoalsViewModel()
    /// Separate from `logsViewModel` — the timeline section can browse past dates independently
    /// of "오늘"'s own data (score ring, quick-log button states), which must always reflect today.
    @StateObject private var timelineLogsViewModel = LogsViewModel()
    @State private var timelineDate = Date()
    @State private var showTimelineDatePicker = false
    @State private var showSettings = false
    @State private var showSleepReport = false
    /// Distinguishes "still loading" from "genuinely empty" for the very first load — after
    /// that, quick-log refreshes flip isLoading again but shouldn't blank the whole screen.
    @State private var hasLoadedOnce = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    /// Gates the interactive tour (see OnboardingTour.swift) — spotlights real on-screen elements
    /// instead of a separate slide deck, so it stays accurate to whatever's actually on screen.
    /// Keyed per-account (see `init` below), not just per-device — a device-global key would mean
    /// a second account signed into the same device (very common while testing) inherits the
    /// first account's "already seen it" state and silently never sees the tour, even though it's
    /// genuinely that account's first time.
    @AppStorage private var hasSeenOnboarding: Bool
    /// Separate from `hasSeenOnboarding` on purpose — that flag flips permanently the moment the
    /// user dismisses the tour, regardless of whether the default-goal backfill in the same
    /// `.task` actually succeeded (e.g. a cold-start network hiccup on first launch). Gating the
    /// retry on this instead means a failed attempt gets retried on the next launch too, and it
    /// only ever stops once goals are confirmed present. Also per-account, same reasoning as above.
    @AppStorage private var hasAppliedDefaultGoals: Bool
    @State private var tourStepIndex = 0
    @Environment(\.scenePhase) private var scenePhase

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        // RootView recreates TodayView (`.id(authViewModel.session?.user.id)`) on every account
        // switch, so this only ever runs once per signed-in account — safe to derive the storage
        // key from the session available at that moment.
        let accountKey = authViewModel.session?.user.id.uuidString ?? "anonymous"
        _hasSeenOnboarding = AppStorage(wrappedValue: false, "hasSeenOnboarding_\(accountKey)")
        _hasAppliedDefaultGoals = AppStorage(wrappedValue: false, "hasAppliedDefaultGoals_\(accountKey)")
    }

    // The session shown below this header is keyed off the KST calendar date (see the KST
    // session model in docs/api-contract.md), so the header has to agree with it even on a
    // device set to a non-KST time zone.
    private static let dateHeadingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let carryoverWakeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    private static let timelineDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()

    /// `DatePicker` hands back a `Date` anchored to whatever calendar day it displayed, using the
    /// *device's* timezone — reformatting that instant through a KST-pinned formatter can land on
    /// a different calendar date whenever the device's UTC offset is ahead of KST's (+9): e.g.
    /// local midnight of a picked day in a UTC+13 zone is still the previous day in KST.
    /// Re-anchoring to noon KST of the same Y/M/D the picker displayed keeps the queried date
    /// matching what's on screen regardless of device timezone.
    private func kstAnchoredDate(from date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var kstCalendar = Calendar(identifier: .gregorian)
        kstCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return kstCalendar.date(from: DateComponents(year: components.year, month: components.month, day: components.day, hour: 12)) ?? date
    }

    private var isTimelineDateToday: Bool {
        Calendar.current.isDate(kstAnchoredDate(from: timelineDate), inSameDayAs: kstAnchoredDate(from: Date()))
    }

    private func shiftTimelineDate(byDays days: Int) {
        guard let shifted = Calendar.current.date(byAdding: .day, value: days, to: timelineDate) else { return }
        timelineDate = min(shifted, Date())
    }

    /// Computed once per render from the raw logs — see RoutineDayMetrics.swift for the actual
    /// (unit-tested) logic. Consolidating to one call avoids re-sorting/re-walking logsViewModel.logs
    /// separately for every derived value below.
    private var dayMetrics: RoutineDayMetrics {
        computeRoutineDayMetrics(from: logsViewModel.logs)
    }

    private var streakDays: Int { computeStreakDays(from: streakViewModel.points) }

    private var actualWakeTimeLabel: String? {
        dayMetrics.actualWakeTime.map { Self.timeOnlyFormatter.string(from: $0) }
    }

    private var studyMinutesLabel: String {
        durationLabel(minutes: dayMetrics.totalStudyMinutes, hasClosedSession: dayMetrics.hasClosedStudySession)
    }

    private var mealMinutesLabel: String {
        durationLabel(minutes: dayMetrics.totalMealMinutes, hasClosedSession: dayMetrics.hasClosedMealSession)
    }

    /// Re-derives today's reminders from whatever's currently loaded — cheap enough to call
    /// after every refresh so a just-logged 기상/취침 cancels its own reminder immediately
    /// instead of waiting for the next full data load.
    private func scheduleNotificationsIfEnabled() {
        guard notificationsEnabled else { return }
        NotificationManager.scheduleTodayReminders(
            hasLoggedWake: dayMetrics.hasLoggedWake,
            hasLoggedSleep: dayMetrics.hasLoggedSleep,
            wakeGoalTime: scoreViewModel.entry(for: GoalTargetType.wakeTime)?.targetValue
        )
    }

    private var personalScoreDelta: Int? {
        guard let today = scoreViewModel.dailyScore,
              let baseline = computePersonalAverageScore(from: streakViewModel.points) else { return nil }
        return today - baseline
    }

    /// Explains why the metric cards/quick-log buttons below are showing yesterday's still-open
    /// session instead of a blank "오늘" — otherwise a carried-over session looks unexplained,
    /// and the 24h auto-close (see docs/api-contract.md) would just silently end their day.
    ///
    /// The 24h window is measured from the *first* 기상 log that opened the session, not from
    /// `dayMetrics.wakeOpenSince` (which tracks the most recent 기상, since a same-session 기상
    /// re-tap doesn't reset the server's auto-close clock) — using the wrong one here would show
    /// several hours more headroom than the session actually has left.
    private var carryoverBannerText: String? {
        guard logsViewModel.isCarryoverSession, let wakeTime = dayMetrics.actualWakeTime else { return nil }
        let elapsedHours = Date().timeIntervalSince(wakeTime) / 3600
        let remainingHours = max(0, Int((24 - elapsedHours).rounded(.up)))
        return "\(Self.carryoverWakeFormatter.string(from: wakeTime))에 기상하신 뒤 아직 취침을 기록하지 않았어요. 약 \(remainingHours)시간 후 자동으로 하루가 마감돼요."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if hasLoadedOnce {
                        scoreRingCard
                        metricCardsRow
                        if let carryoverBannerText {
                            carryoverBanner(text: carryoverBannerText)
                        }
                    } else {
                        loadingPlaceholder
                    }

                    quickLogSection

                    if hasLoadedOnce {
                        timelineSection
                    }

                    if let errorMessage = logsViewModel.errorMessage ?? scoreViewModel.errorMessage {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                            Button("다시 시도") {
                                Task {
                                    await scoreViewModel.refreshTodayScore()
                                    await logsViewModel.loadTodayIncludingCarryover()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let scoreTask: Void = scoreViewModel.refreshTodayScore()
                async let logsTask: Void = logsViewModel.loadTodayIncludingCarryover()
                // 14 days, not more — TrendViewModel fires one /scores + one /logs call per day
                // concurrently, and piling on top of the score/logs calls already in flight here
                // risks tripping the 60-per-minute rate limit on a single screen load.
                // Only streak/personal-average (dailyScore-based) are read from this instance —
                // skip the per-day /logs fetch that mealIrregularityRate would otherwise need.
                async let streakTask: Void = streakViewModel.loadTrend(days: 14, includingMealData: false)
                _ = await (scoreTask, logsTask, streakTask)
                if !hasAppliedDefaultGoals {
                    await goalsViewModel.loadGoals()
                    let hadNoGoalsYet = !goalsViewModel.hasWakeGoal && !goalsViewModel.hasStudyGoal
                    await goalsViewModel.applyDefaultGoalsIfMissing()
                    if goalsViewModel.hasWakeGoal && goalsViewModel.hasStudyGoal {
                        hasAppliedDefaultGoals = true
                        // scoreTask above already ran with no goals in place, so the score
                        // ring/목표 카드 would otherwise show "목표 없음" for one render even
                        // though defaults were just applied a moment later.
                        if hadNoGoalsYet {
                            await scoreViewModel.refreshTodayScore()
                        }
                    }
                }
                hasLoadedOnce = true
                scheduleNotificationsIfEnabled()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: authViewModel)
            }
            .sheet(isPresented: $showSleepReport) {
                SleepReportSheet(viewModel: sleepReportViewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            // Re-derive today's reminders on foreground too, not just first load — otherwise
            // reopening the app later the same day (or the next day) leaves stale/missing
            // reminders until some other refresh happens to fire.
            if newPhase == .active, hasLoadedOnce {
                scheduleNotificationsIfEnabled()
            }
        }
        .onChange(of: notificationsEnabled) { _, isOn in
            // SettingsView flips this same @AppStorage key when the toggle is switched on, but
            // it has no access to today's logs to actually schedule anything — without this,
            // turning the toggle on schedules nothing until the next unrelated refresh happens to
            // fire (task/scenePhase/a quick-log tap).
            if isOn, hasLoadedOnce {
                scheduleNotificationsIfEnabled()
            }
        }
        // Waits for hasLoadedOnce so the tour's targets (score ring, quick-log buttons) are
        // actually on screen in their real state before spotlighting them. Must be attached here
        // (at or above the NavigationStack containing the `.tourAnchor(_:)`-tagged views) rather
        // than on some other, disconnected view — see tourOverlay's doc comment.
        .tourOverlay(
            isActive: hasLoadedOnce && !hasSeenOnboarding,
            stepIndex: $tourStepIndex,
            isRealActionSatisfied: dayMetrics.hasLoggedWake,
            onFinish: { hasSeenOnboarding = true }
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("루티니티")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.routinityHeadline)
                Text("오늘 루틴을 기록해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.routinityCard, in: Circle())
            }
            .tourAnchor("settingsButton")
        }
    }

    /// Shown only until the first load resolves — without this, the ring/cards briefly rendered
    /// their empty state ("-", "목표 없음") indistinguishably from actually having no goals,
    /// which reads as data having vanished rather than still loading.
    private var loadingPlaceholder: some View {
        VStack {
            ProgressView()
                .tint(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .routinityCard(glow: true)
    }

    private var scoreRingCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                if let score = scoreViewModel.dailyScore {
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(
                            AngularGradient(colors: [.routinityOrange, .routinityPink], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(scoreViewModel.dailyScore.map { "\($0)" } ?? "-")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("TODAY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let delta = personalScoreDelta {
                        Text(delta == 0 ? "평소와 비슷" : "평소보다 \(delta > 0 ? "+" : "")\(delta)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(delta > 0 ? Color.routinityGreen : (delta < 0 ? Color.routinityPink : Color.secondary))
                    }
                }
            }
            .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: 10) {
                Text(Self.dateHeadingFormatter.string(from: Date()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Self.weekdayFormatter.string(from: Date()))
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                statPill(value: "\(streakDays)일", label: "연속 달성")
            }
            Spacer()
        }
        .routinityCard(glow: true)
        .tourAnchor("score")
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 56)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var metricCardsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                icon: "sun.max.fill",
                tint: .routinityOrange,
                title: "기상",
                value: actualWakeTimeLabel ?? "-",
                subtitle: scoreViewModel.entry(for: GoalTargetType.wakeTime).map { "목표 \($0.targetValue)" } ?? "목표 없음"
            )
            metricCard(
                icon: "book.fill",
                tint: .routinityCyan,
                title: "공부",
                value: studyMinutesLabel,
                subtitle: scoreViewModel.entry(for: GoalTargetType.studyDuration).map { "목표 \($0.targetValue)분" } ?? "목표 없음"
            )
            mealRestCard
        }
    }

    /// Meal and rest share this card slot as two separate numbers rather than one merged figure
    /// (넓게 보면 식사도 휴식의 일종) — 휴식 is a running snapshot since 기상 (see
    /// RoutineDayMetrics.restMinutesSoFar), so it reads "-" until 기상 is logged. Each row reuses
    /// the same icon-badge + bold-value language as metricCard, just twice at half height, so this
    /// card doesn't read as a different visual style stacked next to 기상/공부.
    private var mealRestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            mealRestRow(icon: "fork.knife", tint: .routinityPink, value: mealMinutesLabel, label: "식사")
            Spacer(minLength: 0)
            mealRestRow(icon: "cup.and.saucer.fill", tint: .routinityViolet, value: dayMetrics.restMinutesSoFar.map { "\($0)분" } ?? "-", label: "휴식")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .routinityCard(padding: 12)
    }

    private func mealRestRow(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metricCard(icon: String, tint: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .routinityCard(padding: 12)
    }

    private func carryoverBanner(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.routinityOrange)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinityCard(padding: 12)
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("간편 기록")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // 기상↔취침: 기상(시작)은 절대 잠기지 않는다. 하지만 취침(종료)은 식사·공부가 아직
            // 진행 중이면 잠근다 — 그 상태로 취침을 기록하면 식사/공부 세션이 닫을 방법 없이 영원히
            // 진행 중으로 남기 때문에, 먼저 그것들을 끝내도록 유도한다.
            toggleLogButton(
                startType: .wake, endType: .sleep, openSince: dayMetrics.wakeOpenSince, showsStopwatch: false,
                isLocked: dayMetrics.isSleepButtonLocked, lockedReason: "식사·공부를 먼저 마쳐주세요"
            )
            .tourAnchor("wakeButton")

            // 식사 시작↔종료: 시작은 지금 깨어있는 상태(기상~취침 사이)가 아니거나 공부가 진행 중이면
            // 잠금. 이미 진행 중인 종료는 절대 안 잠근다(위 취침 잠금 덕분에 안전하게 항상 닫을 수 있음).
            toggleLogButton(
                startType: .mealStart, endType: .mealEnd, openSince: dayMetrics.mealOpenSince, showsStopwatch: false,
                isLocked: dayMetrics.isMealButtonLocked, lockedReason: "기상 후, 공부 중이 아닐 때 가능해요"
            )

            // 공부 시작↔종료: 위 식사와 동일한 규칙, 진행 중일 때 실시간 스톱워치 표시.
            toggleLogButton(
                startType: .studyStart, endType: .studyEnd, openSince: dayMetrics.studyOpenSince, showsStopwatch: true,
                isLocked: dayMetrics.isStudyButtonLocked, lockedReason: "기상 후, 식사 중이 아닐 때 가능해요"
            )
        }
    }

    private func toggleLogButton(
        startType: LogEntry.LogType,
        endType: LogEntry.LogType,
        openSince: Date?,
        showsStopwatch: Bool,
        isLocked: Bool,
        lockedReason: String? = nil
    ) -> some View {
        let inProgress = openSince != nil
        let type = inProgress ? endType : startType
        let isRecordingThisPair = logsViewModel.isRecording == startType || logsViewModel.isRecording == endType
        return Button {
            recordAndRefresh(type)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.routinityViolet.opacity(isLocked ? 0.12 : 0.3))
                        .frame(width: 40, height: 40)
                    if isRecordingThisPair {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isLocked ? "lock.fill" : type.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(isLocked ? Color.secondary : Color.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isLocked ? Color.secondary : Color.white)
                    if isLocked, let lockedReason {
                        Text(lockedReason)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if inProgress, showsStopwatch, let start = openSince {
                        Text(start, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.routinityCyan)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .routinityCard(padding: 12)
        .disabled(logsViewModel.isRecording != nil || isLocked)
    }

    /// Raw log list for a browsable date, inline at the bottom of 오늘 instead of a separate
    /// 타임라인 tab/menu item. Defaults to today but has its own date picker + `LogsViewModel`
    /// (`timelineLogsViewModel`) so browsing past days doesn't disturb 오늘's own score
    /// ring/quick-log button state, which must always reflect the actual current session.
    /// A live 식사/공부/휴식 분배 for whichever date the timeline picker has selected — computed
    /// straight from that date's already-fetched logs, so it's available immediately even for an
    /// in-progress session with no 취침 yet (unlike the AI 코치 리포트's `time_breakdown`, which the
    /// backend can only fill in once the 기상~취침 window is actually closed).
    private var timelineTimeBreakdown: TimeBreakdown? {
        let logs = timelineLogsViewModel.logs
        // restMinutesSoFar measures through to `now` whenever the session has no 취침 closing it
        // (see RoutineDayMetrics) — correct for 오늘's own still-open session, but browsing to a
        // past date with an abandoned/never-closed session would otherwise measure "so far" all
        // the way to the real current moment, producing an absurdly large 휴식 value for a day
        // that's long over. Cap at that date's own last log instead, unless it's actually today.
        let referenceNow = isTimelineDateToday ? Date() : (logs.map(\.timestamp).max() ?? Date())
        let metrics = computeRoutineDayMetrics(from: logs, now: referenceNow)
        guard metrics.hasLoggedWake else { return nil }
        let meal = metrics.totalMealMinutes
        let study = metrics.totalStudyMinutes
        let rest = metrics.restMinutesSoFar ?? 0
        return TimeBreakdown(activeMinutes: meal + study + rest, mealMinutes: meal, studyMinutes: study, restMinutes: rest)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("타임라인")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 2) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { shiftTimelineDate(byDays: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }

                    Button {
                        showTimelineDatePicker = true
                    } label: {
                        Text(Self.timelineDayFormatter.string(from: timelineDate))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(minWidth: 84)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { shiftTimelineDate(byDays: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isTimelineDateToday ? Color.secondary.opacity(0.3) : .secondary)
                            .frame(width: 28, height: 28)
                    }
                    .disabled(isTimelineDateToday)
                }
                .buttonStyle(.plain)
            }

            if let breakdown = timelineTimeBreakdown {
                TimeBreakdownChart(breakdown: breakdown)
            }

            if timelineLogsViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let errorMessage = timelineLogsViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if timelineLogsViewModel.logs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("이 날짜에는 기록이 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .routinityCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(timelineLogsViewModel.logs.sorted { $0.timestamp < $1.timestamp }) { log in
                        timelineRow(log)
                    }
                }
            }
        }
        .task(id: timelineDate) {
            await timelineLogsViewModel.loadLogs(on: kstAnchoredDate(from: timelineDate))
        }
        .sheet(isPresented: $showTimelineDatePicker) {
            NavigationStack {
                DatePicker("날짜", selection: $timelineDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.routinityViolet)
                    .padding()
                    .navigationTitle("날짜 선택")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("완료") { showTimelineDatePicker = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private func timelineRow(_ log: LogEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.routinityViolet.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: log.type.symbolName)
                    .font(.footnote)
                    .foregroundStyle(Color.routinityViolet)
            }
            Text(log.type.displayName)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text(log.timestamp, style: .time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .routinityCard(padding: 12)
    }

    private func recordAndRefresh(_ type: LogEntry.LogType) {
        Task {
            await logsViewModel.recordLog(type: type)
            await scoreViewModel.refreshTodayScore()
            guard logsViewModel.errorMessage == nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            scheduleNotificationsIfEnabled()

            // 취침을 기록하면 그 시점 데이터로 오늘 리포트를 생성해서 바로 보여준다.
            if type == .sleep {
                await sleepReportViewModel.loadReport(period: .daily)
                showSleepReport = true
            }
        }
    }
}

private extension ScoreViewModel {
    func entry(for targetType: String) -> ScoreEntry? {
        scores.first { $0.targetType == targetType }
    }
}

/// Shown right after 취침 is logged — the report generated from that moment's data.
private struct SleepReportSheet: View {
    @ObservedObject var viewModel: ReportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let report = viewModel.report {
                        Text(report.content)
                            .font(.body)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .routinityCard()

                        if let suggestedAction = viewModel.report?.suggestedAction {
                            SuggestedActionCard(action: suggestedAction)
                        }

                        if let breakdown = viewModel.report?.timeBreakdown {
                            TimeBreakdownChart(breakdown: breakdown)
                        }
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .navigationTitle("오늘 리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    TodayView(authViewModel: AuthViewModel())
}
