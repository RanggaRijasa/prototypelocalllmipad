//
//  ModelSelectionView.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import SwiftData
import SwiftUI

struct ModelSelectionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedAnalysisEngine") private var selectedEngineRawValue = AnalysisEngine.simpleRules.rawValue
    @Query(sort: \StoryEvent.date, order: .reverse) private var events: [StoryEvent]
    @ObservedObject private var library: LocalModelLibrary
    @ObservedObject private var runtimeSession: LocalLLMRuntimeSession
    @State private var activeSheet: ModelSheet?

    init(
        library: LocalModelLibrary,
        runtimeSession: LocalLLMRuntimeSession
    ) {
        self.library = library
        self.runtimeSession = runtimeSession
    }

    private var selectedEngine: AnalysisEngine {
        AnalysisEngine(rawValue: selectedEngineRawValue) ?? .simpleRules
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Engine") {
                    Picker("Analysis Engine", selection: $selectedEngineRawValue) {
                        ForEach(AnalysisEngine.allCases) { engine in
                            Text(engine.title).tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    LabeledContent("Selected", value: selectedEngine.title)
                }

                Section("Local Model") {
                    if let installed = library.selectedInstalledModel {
                        LocalModelStatusView(installed: installed, runtimeState: runtimeSession.state)

                        if installed.model.runtime == .liteRTLM {
                            Button {
                                Task {
                                    await runtimeSession.load(
                                        model: installed,
                                        configuration: library.configuration
                                    )
                                }
                            } label: {
                                Label(
                                    runtimeSession.isLoaded ? "Reload Model" : "Load Model",
                                    systemImage: "memorychip"
                                )
                            }
                            .disabled(runtimeSession.isBusy)

                            Button {
                                runtimeSession.offload()
                            } label: {
                                Label("Offload From Memory", systemImage: "eject")
                            }
                            .disabled(!runtimeSession.isLoaded || runtimeSession.isBusy)
                        } else {
                            Text("Choose a LiteRT-LM `.litertlm` model to enable local analytics generation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("No local model selected", systemImage: "cpu")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        activeSheet = .configuration
                    } label: {
                        Label("Configurations", systemImage: "slider.horizontal.3")
                    }

                    Text(library.runtimeReadinessMessage())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Recommended Models") {
                    ForEach(library.availableModels) { model in
                        LocalModelRow(
                            model: model,
                            isInstalled: library.isInstalled(model),
                            isSelected: library.selectedModelID == model.id,
                            status: library.installStatus(for: model),
                            progress: library.downloadProgress?.modelID == model.id ? library.downloadProgress : nil
                        ) {
                            if library.isInstalled(model) {
                                runtimeSession.offload()
                                library.select(model)
                                selectedEngineRawValue = AnalysisEngine.localLLM.rawValue
                            } else {
                                runtimeSession.offload()
                                selectedEngineRawValue = AnalysisEngine.localLLM.rawValue
                                Task {
                                    await library.download(model)
                                }
                            }
                        }
                    }
                }

                Section("Import") {
                    Button {
                        activeSheet = .importModel
                    } label: {
                        Label("Import from Hugging Face", systemImage: "link.badge.plus")
                    }
                }

                Section("Analytics Prompt") {
                    Text(library.analyticsPrompt(for: events))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button {
                        activeSheet = .configuration
                    } label: {
                        Label("Edit Prompt and Context", systemImage: "text.badge.plus")
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
            .navigationTitle("Models")
            .task {
                library.repairCompletedDownloads()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    runtimeSession.offload()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .configuration:
                    LocalLLMConfigurationSheet(library: library)
                case .importModel:
                    ImportHuggingFaceModelSheet(library: library) {
                        selectedEngineRawValue = AnalysisEngine.localLLM.rawValue
                    }
                }
            }
        }
    }
}

private enum ModelSheet: Identifiable {
    case configuration
    case importModel

    var id: String {
        switch self {
        case .configuration: "configuration"
        case .importModel: "importModel"
        }
    }
}

private struct LocalModelStatusView: View {
    let installed: InstalledLocalLLMModel
    let runtimeState: LocalLLMRuntimeSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(installed.model.name, systemImage: runtimeState.isLoaded ? "memorychip.fill" : "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(runtimeState.isLoaded ? .blue : .green)

                Spacer()

                Text(installed.model.runtime.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(LocalModelLibrary.formattedBytes(installed.downloadedBytes))
                Text("Installed \(installed.installedAt, format: .dateTime.month().day())")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(runtimeState.message)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch runtimeState {
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

private struct LocalModelRow: View {
    let model: LocalLLMModel
    let isInstalled: Bool
    let isSelected: Bool
    let status: String
    let progress: LocalLLMDownloadProgress?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.headline)

                        if model.isRecommended {
                            Text("Best")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Label(model.runtime.title, systemImage: "cpu")
                        Label(status, systemImage: "internaldrive")
                        if let memory = model.estimatedPeakMemoryInBytes {
                            Label("Peak \(LocalModelLibrary.formattedBytes(memory))", systemImage: "memorychip")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }

            if let progress, progress.isDownloading {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress.fractionCompleted)
                    Text(progress.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: action) {
                Label(isInstalled ? "Use Model" : "Download", systemImage: isInstalled ? "checkmark" : "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .disabled(progress?.isDownloading == true)
            .accessibilityLabel(isInstalled ? "Use \(model.name)" : "Download \(model.name)")
        }
        .padding(.vertical, 8)
    }
}

private struct ImportHuggingFaceModelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LocalModelLibrary
    let onImport: () -> Void

    @State private var modelName = ""
    @State private var urlsText = ""
    @State private var runtime: LocalLLMRuntime = .liteRTLM
    @State private var downloadAfterImport = true
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    TextField("Display name", text: $modelName)
                    Picker("Runtime", selection: $runtime) {
                        ForEach(LocalLLMRuntime.allCases) { runtime in
                            Text(runtime.title).tag(runtime)
                        }
                    }
                }

                Section("Hugging Face Links") {
                    TextEditor(text: $urlsText)
                        .frame(minHeight: 140)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Hugging Face model file URLs")

                    Text("Paste a model page URL, or paste one file URL per line for `.litertlm`, `.task`, `model.yaml`, and checkpoint files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Download after import", isOn: $downloadAfterImport)
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        Task {
                            await createModel()
                        }
                    }
                    .disabled(isResolving)
                }
            }
        }
    }

    @MainActor
    private func createModel() async {
        isResolving = true
        errorMessage = nil

        do {
            let model = try await LocalModelCatalog.importedModel(name: modelName, urlsText: urlsText, runtime: runtime)
            library.addCustomModel(model)
            onImport()

            if downloadAfterImport {
                Task {
                    await library.download(model)
                }
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isResolving = false
    }
}

private struct LocalLLMConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LocalModelLibrary

    @State private var draft: LocalLLMConfiguration
    @State private var selectedTab: ConfigurationTab = .model

    init(library: LocalModelLibrary) {
        self.library = library
        _draft = State(initialValue: library.configuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Configuration", selection: $selectedTab) {
                    ForEach(ConfigurationTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .model:
                    modelConfiguration
                case .prompt:
                    promptConfiguration
                }
            }
            .navigationTitle("Configurations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        library.updateConfiguration(draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private var modelConfiguration: some View {
        Group {
            Section("Max Tokens") {
                Slider(value: maxTokensBinding, in: 128...2048, step: 128)
                LabeledContent("Value", value: "\(draft.maxTokens)")
            }

            Section("TopK") {
                Slider(value: topKBinding, in: 1...128, step: 1)
                LabeledContent("Value", value: "\(draft.topK)")
            }

            Section("TopP") {
                Slider(value: $draft.topP, in: 0.1...1.0, step: 0.01)
                LabeledContent("Value", value: draft.topP.formatted(.number.precision(.fractionLength(2))))
            }

            Section("Temperature") {
                Slider(value: $draft.temperature, in: 0.0...2.0, step: 0.05)
                LabeledContent("Value", value: draft.temperature.formatted(.number.precision(.fractionLength(2))))
            }

            Section("Runtime") {
                Picker("Accelerator", selection: $draft.accelerator) {
                    ForEach(LocalLLMAccelerator.allCases) { accelerator in
                        Text(accelerator.title).tag(accelerator)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Enable thinking", isOn: $draft.enableThinking)
                Toggle("Enable speculative decoding", isOn: $draft.enableSpeculativeDecoding)
            }
        }
    }

    private var promptConfiguration: some View {
        Group {
            Section("System Prompt") {
                TextEditor(text: $draft.systemPrompt)
                    .frame(minHeight: 260)
                    .accessibilityLabel("System prompt")
            }

            Section("Context") {
                TextEditor(text: $draft.contextNotes)
                    .frame(minHeight: 160)
                    .accessibilityLabel("Context notes")
            }

            Section {
                Button("Restore default") {
                    draft.systemPrompt = LocalLLMConfiguration.defaultSystemPrompt
                    draft.contextNotes = LocalLLMConfiguration.defaultContextNotes
                }
            }
        }
    }

    private var maxTokensBinding: Binding<Double> {
        Binding(
            get: { Double(draft.maxTokens) },
            set: { draft.maxTokens = Int($0) }
        )
    }

    private var topKBinding: Binding<Double> {
        Binding(
            get: { Double(draft.topK) },
            set: { draft.topK = Int($0) }
        )
    }

    private enum ConfigurationTab: String, CaseIterable, Identifiable {
        case model
        case prompt

        var id: String { rawValue }

        var title: String {
            switch self {
            case .model: "Model Configs"
            case .prompt: "System Prompt"
            }
        }
    }
}

#Preview {
    ModelSelectionView(
        library: LocalModelLibrary(),
        runtimeSession: LocalLLMRuntimeSession()
    )
        .modelContainer(for: StoryEvent.self, inMemory: true)
}
