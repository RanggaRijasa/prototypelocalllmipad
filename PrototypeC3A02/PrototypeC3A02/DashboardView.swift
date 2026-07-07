//
//  DashboardView.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedAnalysisEngine") private var selectedEngineRawValue = AnalysisEngine.simpleRules.rawValue
    @AppStorage(LocalModelLibrary.generatedInsightUserDefaultsKey) private var generatedInsightData = Data()
    @Query(sort: \StoryEvent.date) private var events: [StoryEvent]
    @ObservedObject private var library: LocalModelLibrary
    @ObservedObject private var runtimeSession: LocalLLMRuntimeSession
    @State private var activeSheet: DashboardSheet?
    @State private var insightScope: DashboardInsightScope = .weekly
    @State private var insightDate = Date()

    init(
        library: LocalModelLibrary,
        runtimeSession: LocalLLMRuntimeSession
    ) {
        self.library = library
        self.runtimeSession = runtimeSession
    }

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top)
            ]
        } else {
            [GridItem(.flexible(), spacing: 16, alignment: .top)]
        }
    }

    private var generatedInsight: GeneratedLLMAnalyticsInsight? {
        guard !generatedInsightData.isEmpty else { return nil }
        return try? JSONDecoder().decode(GeneratedLLMAnalyticsInsight.self, from: generatedInsightData)
    }

    private var selectedEngine: AnalysisEngine {
        AnalysisEngine(rawValue: selectedEngineRawValue) ?? .simpleRules
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No dashboard data",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Add story events to see charts and generated insights.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ChartCard(
                                    title: "Mood by Scene",
                                    subtitle: "How moods are distributed across daily moments."
                                ) {
                                    MoodBucketChart(
                                        buckets: AnalyticsBuilder.moodBucketsByScene(from: events),
                                        xTitle: "Scene"
                                    )
                                }

                                ChartCard(
                                    title: "Mood by Place",
                                    subtitle: "Where different moods tend to appear."
                                ) {
                                    MoodBucketChart(
                                        buckets: AnalyticsBuilder.moodBucketsByPlace(from: events),
                                        xTitle: "Place"
                                    )
                                }

                                ChartCard(
                                    title: "Mood over Time",
                                    subtitle: "Average daily mood score from 1 to 6."
                                ) {
                                    MoodTimelineChart(points: AnalyticsBuilder.dailyMoodPoints(from: events))
                                }

                                ChartCard(
                                    title: "Event Volume",
                                    subtitle: "How many story entries are logged each day."
                                ) {
                                    DailyEventCountChart(points: AnalyticsBuilder.dailyEventCounts(from: events))
                                }

                                ChartCard(
                                    title: "Challenging Moods",
                                    subtitle: "Share of sad, angry, tired, or scared moments by scene."
                                ) {
                                    SceneChallengeChart(points: AnalyticsBuilder.challengingMoodByScene(from: events))
                                }

                                ChartCard(
                                    title: "Top Activities",
                                    subtitle: "Activities that appear most often in the story log."
                                ) {
                                    ActivityCountChart(points: AnalyticsBuilder.topActivities(from: events))
                                }
                            }

                            if let generatedInsight {
                                GeneratedLLMInsightCard(insight: generatedInsight)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .generateInsight
                        } label: {
                            Label("Generate Insight", systemImage: "sparkles")
                        }
                        .disabled(events.isEmpty)

                        if generatedInsight != nil {
                            Button(role: .destructive) {
                                library.clearGeneratedInsight()
                            } label: {
                                Label("Clear Generated Insight", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Dashboard Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
            .task {
                library.repairCompletedDownloads(showMessage: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    runtimeSession.offload()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .generateInsight:
                    DashboardInsightGenerationSheet(
                        library: library,
                        runtimeSession: runtimeSession,
                        selectedEngine: selectedEngine,
                        events: events,
                        scope: $insightScope,
                        selectedDate: $insightDate
                    ) { selectedEvents in
                        await generateAnalytics(using: selectedEvents)
                    }
                }
            }
        }
    }

    @MainActor
    private func generateAnalytics(using selectedEvents: [StoryEvent]) async -> Bool {
        if selectedEngine == .appleFoundationModels {
            do {
                let insight = try await AppleFoundationModelsRuntime.generateAnalytics(
                    events: selectedEvents,
                    configuration: library.configuration
                )
                library.saveGeneratedInsight(insight)
                selectedEngineRawValue = AnalysisEngine.appleFoundationModels.rawValue
                return true
            } catch {
                library.lastMessage = error.localizedDescription
                return false
            }
        }

        guard let installed = library.selectedInstalledModel else {
            library.lastMessage = "Download or select a LiteRT-LM model before generating analytics."
            return false
        }

        do {
            if !runtimeSession.isLoaded(model: installed) {
                await runtimeSession.load(
                    model: installed,
                    configuration: library.configuration
                )
            }

            let insight = try await runtimeSession.generateAnalytics(
                events: selectedEvents,
                configuration: library.configuration,
                model: installed
            )
            library.saveGeneratedInsight(insight)
            selectedEngineRawValue = AnalysisEngine.localLLM.rawValue
            return true
        } catch {
            library.lastMessage = error.localizedDescription
            return false
        }
    }
}

private enum DashboardSheet: Identifiable {
    case generateInsight

    var id: String {
        switch self {
        case .generateInsight: "generateInsight"
        }
    }
}

private enum DashboardInsightScope: String, CaseIterable, Identifiable {
    case all
    case weekly
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .weekly: "7 Days"
        case .day: "Date"
        }
    }

    var description: String {
        switch self {
        case .all:
            "Uses every saved story event."
        case .weekly:
            "Uses the last seven calendar days, including today."
        case .day:
            "Uses only events logged on the selected date."
        }
    }
}

private func dashboardInsightEvents(
    from events: [StoryEvent],
    scope: DashboardInsightScope,
    selectedDate: Date,
    calendar: Calendar = .current
) -> [StoryEvent] {
    switch scope {
    case .all:
        return events
    case .weekly:
        let todayStart = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        return events.filter { $0.date >= start && $0.date < end }
    case .day:
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? selectedDate
        return events.filter { $0.date >= start && $0.date < end }
    }
}

private struct DashboardInsightGenerationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LocalModelLibrary
    @ObservedObject var runtimeSession: LocalLLMRuntimeSession
    let selectedEngine: AnalysisEngine
    let events: [StoryEvent]
    @Binding var scope: DashboardInsightScope
    @Binding var selectedDate: Date
    let onGenerate: ([StoryEvent]) async -> Bool
    @State private var isGenerating = false

    private var scopedEvents: [StoryEvent] {
        dashboardInsightEvents(from: events, scope: scope, selectedDate: selectedDate)
    }

    private var canGenerate: Bool {
        guard !isGenerating else { return false }
        guard !scopedEvents.isEmpty else { return false }
        if selectedEngine == .appleFoundationModels {
            return AppleFoundationModelsRuntime.isAvailable
        }

        guard let installed = library.selectedInstalledModel else { return false }
        return installed.model.runtime == .liteRTLM
            && !runtimeSession.isBusy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    Picker("Use", selection: $scope) {
                        ForEach(DashboardInsightScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scope == .day {
                        DatePicker(
                            "Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                    }

                    LabeledContent("Included Events", value: "\(scopedEvents.count)")

                    Text(scope.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Model") {
                    if selectedEngine == .appleFoundationModels {
                        Label(AppleFoundationModelsRuntime.displayName, systemImage: "sparkles")
                            .foregroundStyle(AppleFoundationModelsRuntime.isAvailable ? Color.blue : Color.secondary)

                        Text(AppleFoundationModelsRuntime.readinessMessage)
                            .font(.caption)
                            .foregroundStyle(AppleFoundationModelsRuntime.isAvailable ? Color.secondary : Color.red)

                        Text("Uses the same system prompt and context as the local model flow. No downloaded `.litertlm` file is needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let installed = library.selectedInstalledModel {
                        Label(installed.model.name, systemImage: runtimeSession.isLoaded ? "memorychip.fill" : "memorychip")
                            .foregroundStyle(runtimeSession.isLoaded ? .blue : .primary)

                        Text(runtimeSession.state.message)
                            .font(.caption)
                            .foregroundStyle(statusColor)

                        if installed.model.runtime == .liteRTLM {
                            Text("The app loads the model only while generating this insight, then offloads it from memory automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if runtimeSession.isLoaded {
                                Button {
                                    runtimeSession.offload()
                                } label: {
                                    Label("Offload Now", systemImage: "eject")
                                }
                                .disabled(runtimeSession.isBusy)
                            }
                        } else {
                            Text("Select a LiteRT-LM `.litertlm` model before generating dashboard analytics.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Download or select a LiteRT-LM model in Models before generating dashboard analytics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task {
                            isGenerating = true
                            defer { isGenerating = false }

                            if await onGenerate(scopedEvents) {
                                dismiss()
                            }
                        }
                    } label: {
                        if isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("Generating Insight")
                            }
                        } else {
                            Label("Generate Dashboard Insight", systemImage: "sparkles")
                        }
                    }
                    .disabled(!canGenerate)

                    if isGenerating {
                        Text("Analyzing \(scopedEvents.count) story events...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if scopedEvents.isEmpty {
                        Text("There are no story events in this data range.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = library.lastMessage {
                    Section("Status") {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Generate Insight")
            .interactiveDismissDisabled(isGenerating)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
            }
        }
    }

    private var statusColor: Color {
        switch runtimeSession.state {
        case .failed:
            .red
        case .loaded:
            .blue
        case .loading, .generating:
            .orange
        case .offloaded:
            .secondary
        }
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
                .frame(height: 260)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary)
        }
    }
}

private struct MoodBucketChart: View {
    let buckets: [ChartBucket]
    let xTitle: String

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value(xTitle, bucket.category),
                y: .value("Events", bucket.count)
            )
            .foregroundStyle(by: .value("Mood", bucket.mood.displayName))
            .position(by: .value("Mood", bucket.mood.displayName))
        }
        .chartXAxisLabel(xTitle)
        .chartYAxisLabel("Events")
        .accessibilityLabel("\(xTitle) mood distribution chart")
        .accessibilityValue("Shows event counts grouped by mood.")
    }
}

private struct MoodTimelineChart: View {
    let points: [DailyMoodPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Average mood", point.averageScore)
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Average mood", point.averageScore)
            )
            .annotation(position: .top) {
                Text("\(point.eventCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYScale(domain: 1...6)
        .chartXAxisLabel("Day")
        .chartYAxisLabel("Mood score")
        .accessibilityLabel("Mood over time chart")
        .accessibilityValue("Shows average mood scores by day.")
    }
}

private struct DailyEventCountChart: View {
    let points: [DailyEventCountPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Events", point.count)
            )
            .foregroundStyle(.blue.gradient)
            .annotation(position: .top) {
                Text("\(point.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxisLabel("Day")
        .chartYAxisLabel("Events")
        .accessibilityLabel("Event volume chart")
        .accessibilityValue("Shows the number of story events logged each day.")
    }
}

private struct SceneChallengeChart: View {
    let points: [SceneChallengePoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Scene", point.scene),
                y: .value("Challenging moods", point.challengingPercent)
            )
            .foregroundStyle(.orange.gradient)
            .annotation(position: .top) {
                Text("\(point.challengingCount)/\(point.totalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxisLabel("Scene")
        .chartYAxisLabel("Percent")
        .accessibilityLabel("Challenging moods by scene chart")
        .accessibilityValue("Shows the percentage of challenging moods for each scene.")
    }
}

private struct ActivityCountChart: View {
    let points: [ActivityCountPoint]

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Events", point.count),
                y: .value("Activity", point.activity)
            )
            .foregroundStyle(.green.gradient)
            .annotation(position: .trailing) {
                Text("\(point.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxisLabel("Events")
        .chartYAxisLabel("Activity")
        .accessibilityLabel("Top activities chart")
        .accessibilityValue("Shows the activities with the most story events.")
    }
}

private struct GeneratedLLMInsightCard: View {
    let insight: GeneratedLLMAnalyticsInsight
    @State private var selectedTrigger: GeneratedLLMCommonTrigger?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Local LLM Insight", systemImage: "memorychip")
                    .font(.headline)

                Spacer()

                Text(insight.modelName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(insight.summary)
                .font(.body)

            CommonTriggersSection(
                triggers: Array(insight.commonTriggers.prefix(6)),
                selectedTrigger: $selectedTrigger
            )

            InsightBulletSection(
                title: "Notable Patterns",
                systemImage: "point.3.connected.trianglepath.dotted",
                items: Array(insight.notablePatterns.prefix(3))
            )

            Divider()

            Text(insight.parentReflectionPrompt)
                .font(.footnote.weight(.medium))

            Text(insight.ethicalNote.isEmpty ? "Model output is reflective and non-diagnostic." : insight.ethicalNote)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Generated \(insight.generatedAt, format: .dateTime.month().day().hour().minute())")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary)
        }
        .alert(item: $selectedTrigger) { trigger in
            Alert(
                title: Text(trigger.title),
                message: Text(trigger.explanation),
                dismissButton: .default(Text("Done"))
            )
        }
    }
}

private struct CommonTriggersSection: View {
    let triggers: [GeneratedLLMCommonTrigger]
    @Binding var selectedTrigger: GeneratedLLMCommonTrigger?

    var body: some View {
        if !triggers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Common Triggers", systemImage: "exclamationmark.bubble")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(triggers) { trigger in
                            Text(trigger.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.background)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(.secondary, lineWidth: 1)
                                }
                                .contentShape(Capsule())
                                .onLongPressGesture {
                                    selectedTrigger = trigger
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("Touch and hold for an explanation.")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct InsightBulletSection: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .padding(.top, 7)
                            .foregroundStyle(.secondary)

                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView(
        library: LocalModelLibrary(),
        runtimeSession: LocalLLMRuntimeSession()
    )
        .modelContainer(for: StoryEvent.self, inMemory: true)
}
