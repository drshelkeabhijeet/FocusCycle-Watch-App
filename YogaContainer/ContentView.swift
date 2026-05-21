//
//  ContentView.swift
//  YogaContainer
//

import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var wc: WatchConnectivityManager
    @EnvironmentObject private var health: CompanionHealthReader

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                CompanionDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent") }
                CompanionPresetsView()
                    .tabItem { Label("Presets", systemImage: "slider.horizontal.3") }
                CompanionHistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                CompanionInsightsView()
                    .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
            }
            ToastOverlay(ack: wc.lastDispatch)
                .padding(.bottom, 60)
                .allowsHitTesting(false)
        }
        .task {
            wc.requestLatestState()
            await health.refresh()
        }
    }
}

// MARK: - Toast

private struct ToastOverlay: View {
    let ack: WatchConnectivityManager.DispatchAck?

    var body: some View {
        Group {
            if let ack {
                HStack(spacing: 8) {
                    Image(systemName: ack.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ack.success ? Color.green : Color.orange)
                    Text(ack.title)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 6, y: 3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ack?.id)
    }
}

// MARK: - Dashboard

private struct CompanionDashboardView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var wc: WatchConnectivityManager
    @EnvironmentObject private var health: CompanionHealthReader

    private func value(_ activity: String, _ keyPath: KeyPath<CompanionStreakSummary, Int>) -> Int {
        store.snapshot?.streaksByActivity[activity]?[keyPath: keyPath] ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pairingBannerIfNeeded
                    sleepBannerIfNeeded
                    statusCard
                    streakCard
                    quickActions
                }
                .padding()
            }
            .navigationTitle("Yoga Asana Timer")
            .refreshable {
                wc.requestLatestState()
                await health.refresh()
            }
        }
    }

    @ViewBuilder
    private var pairingBannerIfNeeded: some View {
        if !wc.isPaired {
            BannerView(
                icon: "applewatch.slash",
                tint: .orange,
                title: "No Apple Watch paired",
                subtitle: "Pair an Apple Watch in the Watch app to sync sessions and start practices remotely."
            )
        } else if !wc.isWatchAppInstalled {
            BannerView(
                icon: "applewatch",
                tint: .blue,
                title: "Install on Apple Watch",
                subtitle: "Open the Watch app on iPhone and install Yoga Asana Timer to begin syncing."
            )
        }
    }

    @ViewBuilder
    private var sleepBannerIfNeeded: some View {
        if let hours = health.lastNightSleepHours, hours < 6 {
            BannerView(
                icon: "moon.zzz",
                tint: .indigo,
                title: String(format: "Only %.1f h sleep last night", hours),
                subtitle: "Consider a longer meditation today to recover."
            )
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(wc.isReachable ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(wc.isReachable ? "Watch reachable" : "Watch offline")
                    .font(.subheadline.weight(.medium))
                if let generatedAt = store.snapshot?.generatedAt {
                    Text("Last sync \(generatedAt.formatted(.relative(presentation: .named)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Waiting for first sync")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.pendingCommands.count > 0 {
                Label("\(store.pendingCommands.count) queued", systemImage: "hourglass")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaks")
                .font(.headline)
            HStack {
                metric("Yoga", value("yoga", \.currentStreak))
                metric("Pranayama", value("pranayama", \.currentStreak))
                metric("Meditation", value("meditation", \.currentStreak))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Start on Watch")
                .font(.headline)
            HStack {
                quickActionButton("Yoga", "figure.yoga", "yoga")
                quickActionButton("Pranayama", "wind", "pranayama")
                quickActionButton("Meditation", "brain.head.profile", "meditation")
            }
        }
    }

    private func quickActionButton(_ title: String, _ icon: String, _ practice: String) -> some View {
        Button {
            wc.sendQuickStart(practice: practice)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!wc.isPaired || !wc.isWatchAppInstalled)
    }
}

private struct BannerView: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Presets

private struct CompanionPresetsView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var wc: WatchConnectivityManager

    @AppStorage("companion.lastApplied.yogaHold") private var yogaHold: Int = 60
    @AppStorage("companion.lastApplied.yogaRest") private var yogaRest: Int = 20
    @AppStorage("companion.lastApplied.yogaAsanas") private var yogaAsanas: Int = 10
    @AppStorage("companion.lastApplied.meditationDuration") private var meditationDuration: Int = 12
    @AppStorage("companion.formHydrated") private var formHydrated: Bool = false

    @State private var userHasEditedYoga = false
    @State private var userHasEditedMeditation = false
    @State private var editingPattern: CompanionPranayamaPreset?

    var body: some View {
        NavigationStack {
            Form {
                if store.snapshot == nil {
                    Section { EmptyStateRow(text: "Open the watch app to begin syncing.") }
                }

                Section("Yoga Preset") {
                    Stepper("Hold: \(yogaHold)s", value: $yogaHold, in: 10...300, step: 10)
                        .onChange(of: yogaHold) { _, _ in userHasEditedYoga = true }
                    Stepper("Rest: \(yogaRest)s", value: $yogaRest, in: 0...180, step: 10)
                        .onChange(of: yogaRest) { _, _ in userHasEditedYoga = true }
                    Stepper("Asanas: \(yogaAsanas)", value: $yogaAsanas, in: 1...240)
                        .onChange(of: yogaAsanas) { _, _ in userHasEditedYoga = true }
                    Button("Apply on Watch") {
                        wc.sendApplyYogaPreset(holdSeconds: yogaHold, restSeconds: yogaRest, asanaCount: yogaAsanas)
                        userHasEditedYoga = false
                    }
                }

                Section("Pranayama Presets") {
                    if (store.snapshot?.presets.pranayama ?? []).isEmpty {
                        EmptyStateRow(text: "Patterns will appear after the first sync.")
                    } else {
                        ForEach(store.snapshot?.presets.pranayama ?? [], id: \.typeRawValue) { preset in
                            Button { editingPattern = preset } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prettyName(preset.typeRawValue))
                                            .font(.body.weight(.medium))
                                        Text("\(preset.inhaleDuration)·\(preset.hold1Duration)·\(preset.exhaleDuration)·\(preset.hold2Duration)  ·  \(preset.cycles) cycles")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                Section("Meditation Preset") {
                    Stepper("Duration: \(meditationDuration)m", value: $meditationDuration, in: 1...120)
                        .onChange(of: meditationDuration) { _, _ in userHasEditedMeditation = true }
                    Button("Apply on Watch") {
                        wc.sendApplyMeditationPreset(durationMinutes: meditationDuration)
                        userHasEditedMeditation = false
                    }
                }
            }
            .navigationTitle("Presets")
            .refreshable { wc.requestLatestState() }
            .onAppear { syncFormFromSnapshot() }
            .onChange(of: store.snapshot?.sequence) { _, _ in
                syncFormFromSnapshot()
            }
            .sheet(item: $editingPattern) { preset in
                PranayamaPatternEditor(initial: preset) { updated in
                    wc.sendApplyPranayamaPreset(updated)
                }
            }
        }
    }

    private func prettyName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "anulom", "anulomvilom", "anulom_vilom": return "Anulom Vilom"
        case "ujjayi": return "Ujjayi"
        case "bhramari": return "Bhramari"
        case "kapalbhati": return "Kapalbhati"
        case "boxbreathing", "box": return "Box Breathing"
        default:
            return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func syncFormFromSnapshot() {
        guard let snapshot = store.snapshot else { return }
        // Once a snapshot is observed, hydrate iOS form once with watch values.
        // After that, persisted iOS values win until the user re-Applies — so
        // re-installs and pre-sync edits survive.
        if !formHydrated {
            yogaHold = max(10, snapshot.presets.yoga.holdSeconds)
            yogaRest = max(0, snapshot.presets.yoga.restSeconds)
            yogaAsanas = max(1, snapshot.presets.yoga.asanaCount)
            meditationDuration = max(1, snapshot.presets.meditation.durationMinutes)
            formHydrated = true
        } else {
            if !userHasEditedYoga {
                yogaHold = max(10, snapshot.presets.yoga.holdSeconds)
                yogaRest = max(0, snapshot.presets.yoga.restSeconds)
                yogaAsanas = max(1, snapshot.presets.yoga.asanaCount)
            }
            if !userHasEditedMeditation {
                meditationDuration = max(1, snapshot.presets.meditation.durationMinutes)
            }
        }
    }
}

// MARK: - Pranayama Pattern Editor

private extension CompanionPranayamaPreset {
    var displayLabel: String {
        switch typeRawValue.lowercased() {
        case "anulom", "anulomvilom", "anulom_vilom": return "Anulom Vilom"
        case "ujjayi": return "Ujjayi"
        case "bhramari": return "Bhramari"
        case "kapalbhati": return "Kapalbhati"
        case "boxbreathing", "box": return "Box Breathing"
        default: return typeRawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

extension CompanionPranayamaPreset: Identifiable {
    public var id: String { typeRawValue }
}

private struct PranayamaPatternEditor: View {
    let initial: CompanionPranayamaPreset
    let onApply: (CompanionPranayamaPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inhale: Int
    @State private var hold1: Int
    @State private var exhale: Int
    @State private var hold2: Int
    @State private var cycles: Int

    init(initial: CompanionPranayamaPreset, onApply: @escaping (CompanionPranayamaPreset) -> Void) {
        self.initial = initial
        self.onApply = onApply
        _inhale = State(initialValue: initial.inhaleDuration)
        _hold1 = State(initialValue: initial.hold1Duration)
        _exhale = State(initialValue: initial.exhaleDuration)
        _hold2 = State(initialValue: initial.hold2Duration)
        _cycles = State(initialValue: initial.cycles)
    }

    private var totalSeconds: Int {
        (inhale + hold1 + exhale + hold2) * cycles
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pattern") {
                    Stepper("Inhale: \(inhale)s", value: $inhale, in: 1...20)
                    Stepper("Hold: \(hold1)s", value: $hold1, in: 0...20)
                    Stepper("Exhale: \(exhale)s", value: $exhale, in: 1...20)
                    Stepper("Hold: \(hold2)s", value: $hold2, in: 0...20)
                    Stepper("Cycles: \(cycles)", value: $cycles, in: 1...30)
                }
                Section {
                    LabeledContent("Total", value: durationString(totalSeconds))
                }
                Section {
                    Button("Reset to original") {
                        inhale = initial.inhaleDuration
                        hold1 = initial.hold1Duration
                        exhale = initial.exhaleDuration
                        hold2 = initial.hold2Duration
                        cycles = initial.cycles
                    }
                }
            }
            .navigationTitle(initial.displayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(CompanionPranayamaPreset(
                            typeRawValue: initial.typeRawValue,
                            inhaleDuration: inhale,
                            hold1Duration: hold1,
                            exhaleDuration: exhale,
                            hold2Duration: hold2,
                            cycles: cycles
                        ))
                        dismiss()
                    }
                }
            }
        }
    }

    private func durationString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 { return "\(minutes)m \(secs)s" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(secs)s"
    }
}

// MARK: - History

private struct CompanionHistoryView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var wc: WatchConnectivityManager
    @State private var selectedActivity = "all"
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $selectedActivity) {
                    Text("All").tag("all")
                    Text("Yoga").tag("yoga")
                    Text("Pranayama").tag("pranayama")
                    Text("Meditation").tag("meditation")
                }
                .pickerStyle(.segmented)

                if filteredEvents.isEmpty {
                    EmptyStateRow(text: store.sessionEvents.isEmpty
                                  ? "No sessions yet. Open the watch app to begin syncing."
                                  : "No \(selectedActivity) sessions match this filter.")
                } else {
                    ForEach(filteredEvents) { event in
                        SessionRow(event: event, durationText: formattedDuration(event.durationSeconds))
                    }
                }
            }
            .navigationTitle("History")
            .refreshable { wc.requestLatestState() }
            .toolbar {
                if !store.sessionEvents.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showingClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    store.clearSessionHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes \(store.sessionEvents.count) session\(store.sessionEvents.count == 1 ? "" : "s") from this iPhone. Watch history is unaffected.")
            }
        }
    }

    private var filteredEvents: [CompanionSessionEvent] {
        if selectedActivity == "all" { return store.sessionEvents }
        return store.sessionEvents.filter { $0.activityTypeRawValue == selectedActivity }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        if m > 0 { return s > 0 ? "\(m)m \(s)s" : "\(m)m" }
        return "\(s)s"
    }
}

// MARK: - Insights

private struct CompanionInsightsView: View {
    @EnvironmentObject private var store: CompanionStore
    @EnvironmentObject private var wc: WatchConnectivityManager
    @EnvironmentObject private var health: CompanionHealthReader

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.snapshot == nil && store.sessionEvents.isEmpty {
                        BannerView(
                            icon: "chart.bar",
                            tint: .blue,
                            title: "No data yet",
                            subtitle: "Open the watch app to begin syncing."
                        )
                    }

                    Text("Wellness Baseline").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        healthTile("Resting HR", value: formatBpm(health.restingHeartRate), icon: "heart.fill", tint: .pink)
                        healthTile("VO2 Max", value: formatVO2(health.vo2Max), icon: "lungs.fill", tint: .teal)
                        healthTile("Blood Oxygen", value: formatPercent(health.latestSpO2), icon: "drop.fill", tint: .blue)
                        healthTile("Respiratory Rate", value: formatBpm(health.latestRespiratoryRate, unit: "br/min"), icon: "wind", tint: .mint)
                        healthTile("Sleep (last night)", value: formatHours(health.lastNightSleepHours), icon: "moon.zzz.fill", tint: .indigo)
                    }
                    if !health.isAuthorized {
                        Text("Grant Health access in Settings → Health → Data Access & Devices → Yoga Asana Timer to populate these tiles.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Total Sessions").font(.headline)
                    HStack {
                        insightBlock("Yoga", totalSessions(for: "yoga"))
                        insightBlock("Pranayama", totalSessions(for: "pranayama"))
                        insightBlock("Meditation", totalSessions(for: "meditation"))
                    }

                    Text("Total Minutes").font(.headline)
                    HStack {
                        insightBlock("Yoga", totalMinutes(for: "yoga"))
                        insightBlock("Pranayama", totalMinutes(for: "pranayama"))
                        insightBlock("Meditation", totalMinutes(for: "meditation"))
                    }

                    Text("Last 30 Days").font(.headline)
                    DailyMinutesChart(events: store.sessionEvents)
                        .frame(height: 220)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
            .navigationTitle("Insights")
            .refreshable {
                wc.requestLatestState()
                await health.refresh()
            }
        }
    }

    private func totalSessions(for activity: String) -> Int {
        store.snapshot?.streaksByActivity[activity]?.totalSessions ?? 0
    }

    private func totalMinutes(for activity: String) -> Int {
        store.snapshot?.streaksByActivity[activity]?.totalMinutes ?? 0
    }

    private func insightBlock(_ title: String, _ value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func healthTile(_ title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatBpm(_ value: Double?, unit: String = "bpm") -> String {
        guard let value else { return "—" }
        return String(format: "%.0f %@", value, unit)
    }
    private func formatVO2(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value * 100)
    }
    private func formatHours(_ value: Double?) -> String {
        guard let value else { return "—" }
        let h = Int(value)
        let m = Int((value - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

private struct DailyMinutesChart: View {
    let events: [CompanionSessionEvent]

    private struct Point: Identifiable {
        let id = UUID()
        let day: Date
        let activity: String
        let minutes: Double
    }

    private var data: [Point] {
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: Date())
        guard let startDay = cal.date(byAdding: .day, value: -29, to: endDay) else { return [] }

        // Aggregate event minutes by (day, activity).
        var bucket: [Date: [String: Double]] = [:]
        for event in events {
            let day = cal.startOfDay(for: event.date)
            guard day >= startDay && day <= endDay else { continue }
            let minutes = Double(event.durationSeconds) / 60.0
            bucket[day, default: [:]][event.activityTypeRawValue, default: 0] += minutes
        }

        var points: [Point] = []
        var cursor = startDay
        while cursor <= endDay {
            let perActivity = bucket[cursor] ?? [:]
            for activity in ["yoga", "pranayama", "meditation"] {
                points.append(Point(day: cursor, activity: activity, minutes: perActivity[activity] ?? 0))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    var body: some View {
        if events.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No sessions in the last 30 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(data) { p in
                BarMark(
                    x: .value("Day", p.day, unit: .day),
                    y: .value("Minutes", p.minutes)
                )
                .foregroundStyle(by: .value("Activity", p.activity.capitalized))
            }
            .chartLegend(position: .bottom)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
    }
}

// MARK: - History row

private struct SessionRow: View {
    let event: CompanionSessionEvent
    let durationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.activityTypeRawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text(durationText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(event.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if hasMetrics {
                FlowMetrics(items: metricItems)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    private var hasMetrics: Bool {
        event.avgHeartRate != nil
            || event.avgRespiratoryRate != nil
            || event.activeEnergyKcal != nil
            || event.hrvPostSdnnMs != nil
            || event.spo2PostPercent != nil
    }

    private var metricItems: [FlowMetrics.Item] {
        var items: [FlowMetrics.Item] = []
        if let hr = event.avgHeartRate {
            items.append(.init(icon: "heart.fill", tint: .pink, text: String(format: "%.0f bpm", hr)))
        }
        if let rr = event.avgRespiratoryRate {
            items.append(.init(icon: "wind", tint: .mint, text: String(format: "%.0f br/min", rr)))
        }
        if let kcal = event.activeEnergyKcal {
            items.append(.init(icon: "flame.fill", tint: .orange, text: String(format: "%.0f kcal", kcal)))
        }
        if let post = event.hrvPostSdnnMs {
            let label: String
            if let pre = event.hrvPreSdnnMs {
                let delta = post - pre
                let sign = delta >= 0 ? "+" : ""
                label = String(format: "HRV %.0f ms (%@%.0f)", post, sign, delta)
            } else {
                label = String(format: "HRV %.0f ms", post)
            }
            items.append(.init(icon: "waveform.path.ecg", tint: .purple, text: label))
        }
        if let post = event.spo2PostPercent {
            let label: String
            if let pre = event.spo2PrePercent {
                let delta = (post - pre) * 100
                let sign = delta >= 0 ? "+" : ""
                label = String(format: "SpO₂ %.0f%% (%@%.1f)", post * 100, sign, delta)
            } else {
                label = String(format: "SpO₂ %.0f%%", post * 100)
            }
            items.append(.init(icon: "drop.fill", tint: .blue, text: label))
        }
        return items
    }
}

private struct FlowMetrics: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let text: String
    }
    let items: [Item]

    var body: some View {
        // Simple wrap layout — chips flow to a new line if needed.
        WrapHStack(spacing: 6, lineSpacing: 4) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.icon).foregroundStyle(item.tint)
                    Text(item.text)
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

/// Minimal flow layout for chip-style metrics on iOS 16+.
private struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 6, lineSpacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        WrapLayout(spacing: spacing, lineSpacing: lineSpacing) { content() }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Shared bits

private struct EmptyStateRow: View {
    let text: String
    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
        .environmentObject(CompanionStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
