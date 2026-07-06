//
//  LiteRTLMAnalyticsRuntime.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(CLiteRTLM)
import CLiteRTLM
#endif

enum LocalLLMRuntimeSessionState: Equatable {
    case offloaded
    case loading(String)
    case loaded(String)
    case generating(String)
    case failed(String)

    var message: String {
        switch self {
        case .offloaded:
            "Model offloaded from memory."
        case .loading(let message), .loaded(let message), .generating(let message), .failed(let message):
            message
        }
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .loading, .generating:
            true
        case .offloaded, .loaded, .failed:
            false
        }
    }
}

enum LocalLLMRuntimeSessionError: LocalizedError {
    case packageMissing
    case unsupportedRuntime(String)
    case modelFileMissing(String)
    case modelNotLoaded
    case noEvents

    var errorDescription: String? {
        switch self {
        case .packageMissing:
            "CLiteRTLM is not linked. Rebuild after adding the LiteRT-LM framework to the app target."
        case .unsupportedRuntime(let runtime):
            "\(runtime) is installed, but this app currently runs LiteRT-LM `.litertlm` models."
        case .modelFileMissing(let name):
            "No `.litertlm` file was found for \(name)."
        case .modelNotLoaded:
            "Load the selected model into memory before generating analytics."
        case .noEvents:
            "Add story events before generating analytics."
        }
    }
}

@MainActor
final class LocalLLMRuntimeSession: ObservableObject {
    @Published private(set) var state: LocalLLMRuntimeSessionState = .offloaded

    private static let primaryAnalyticsEventLimit = 24
    private static let fallbackAnalyticsEventLimit = 10
    private static let idleOffloadDelayNanoseconds: UInt64 = 60 * 1_000_000_000

    private var loadedModelID: String?
    private var idleOffloadTask: Task<Void, Never>?

    #if canImport(UIKit)
    private var memoryWarningObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    #endif

    #if canImport(CLiteRTLM)
    private var engine: Engine?
    private var conversation: Conversation?
    #endif

    init() {
        #if canImport(UIKit)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.offload()
            }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.offload()
            }
        }
        #endif
    }

    var isLoaded: Bool { state.isLoaded }
    var isBusy: Bool { state.isBusy }

    func isLoaded(model installed: InstalledLocalLLMModel) -> Bool {
        isLoaded && loadedModelID == installed.id
    }

    func load(model installed: InstalledLocalLLMModel, configuration: LocalLLMConfiguration) async {
        releaseRuntime()
        loadedModelID = nil
        state = .loading("Loading \(installed.model.name) into memory...")

        do {
            guard installed.model.runtime == .liteRTLM else {
                throw LocalLLMRuntimeSessionError.unsupportedRuntime(installed.model.runtime.title)
            }

            guard let modelURL = Self.liteRTLMModelFileURL(for: installed) else {
                throw LocalLLMRuntimeSessionError.modelFileMissing(installed.model.name)
            }

            try await initializeLiteRTLM(modelURL: modelURL, installed: installed, configuration: configuration)
            loadedModelID = installed.id
            state = .loaded("\(installed.model.name) is loaded for analytics.")
            scheduleIdleOffload()
        } catch {
            releaseRuntime()
            loadedModelID = nil
            state = .failed("Load failed: \(error.localizedDescription)")
        }
    }

    func generateAnalytics(
        events: [StoryEvent],
        configuration: LocalLLMConfiguration,
        model installed: InstalledLocalLLMModel
    ) async throws -> GeneratedLLMAnalyticsInsight {
        guard !events.isEmpty else {
            throw LocalLLMRuntimeSessionError.noEvents
        }

        guard loadedModelID == installed.id else {
            throw LocalLLMRuntimeSessionError.modelNotLoaded
        }

        state = .generating("Generating dashboard analytics with \(installed.model.name)...")
        cancelIdleOffload()

        do {
            let output = try await generateAnalyticsOutput(events: events, configuration: configuration)
            releaseRuntime()
            loadedModelID = nil
            let insight = autoreleasepool {
                LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: installed.model.name)
            }
            state = .offloaded
            return insight
        } catch {
            releaseRuntime()
            loadedModelID = nil
            state = .failed("Generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    func offload() {
        releaseRuntime()
        loadedModelID = nil
        state = .offloaded
    }

    deinit {
        idleOffloadTask?.cancel()
        idleOffloadTask = nil
        #if canImport(UIKit)
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        #endif

        #if canImport(CLiteRTLM)
        conversation = nil
        engine = nil
        #endif
    }

    private func releaseRuntime() {
        cancelIdleOffload()
        #if canImport(CLiteRTLM)
        try? conversation?.cancel()
        conversation = nil
        engine = nil
        #endif
    }

    private func scheduleIdleOffload() {
        cancelIdleOffload()
        idleOffloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.idleOffloadDelayNanoseconds)
            await MainActor.run {
                guard let self, self.isLoaded else { return }
                self.offload()
            }
        }
    }

    private func cancelIdleOffload() {
        idleOffloadTask?.cancel()
        idleOffloadTask = nil
    }

    private static func liteRTLMModelFileURL(for installed: InstalledLocalLLMModel) -> URL? {
        let currentRootURL = LocalModelLibrary.modelStorageDirectory(for: installed.model)
        let savedRootURL = URL(fileURLWithPath: installed.localDirectoryPath, isDirectory: true)
        let rootURLs = [currentRootURL, savedRootURL].reduce(into: [URL]()) { result, url in
            guard !result.contains(where: { $0.path == url.path }) else { return }
            result.append(url)
        }

        for rootURL in rootURLs {
            if let configuredFile = installed.model.files.first(where: { $0.relativePath.hasSuffix(".litertlm") }) {
                let configuredURL = rootURL.appendingPathComponent(configuredFile.relativePath)
                if FileManager.default.fileExists(atPath: configuredURL.path) {
                    return configuredURL
                }
            }

            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }

            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "litertlm" {
                    return fileURL
                }
            }
        }

        return nil
    }

    private static func cacheDirectory() throws -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiteRTLMCache", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    #if canImport(CLiteRTLM)
    private func initializeLiteRTLM(
        modelURL: URL,
        installed: InstalledLocalLLMModel,
        configuration: LocalLLMConfiguration
    ) async throws {
        ExperimentalFlags.optIntoExperimentalAPIs()
        ExperimentalFlags.enableSpeculativeDecoding = configuration.enableSpeculativeDecoding

        let backend: Backend
        switch configuration.accelerator {
        case .cpu:
            backend = .cpu()
        case .gpu:
            backend = .gpu
        }

        let engineConfig = try EngineConfig(
            modelPath: modelURL.path,
            backend: backend,
            maxNumTokens: Self.sessionContextTokenBudget(for: installed.model),
            cacheDir: try Self.cacheDirectory().path
        )
        let engine = Engine(engineConfig: engineConfig)
        try await engine.initialize()

        let conversation = try await Self.makeConversation(engine: engine, configuration: configuration)

        self.engine = engine
        self.conversation = conversation
    }

    private static func makeConversation(
        engine: Engine,
        configuration: LocalLLMConfiguration
    ) async throws -> Conversation {
        let samplerConfig = try SamplerConfig(
            topK: configuration.topK,
            topP: Float(configuration.topP),
            temperature: Float(configuration.temperature)
        )
        let conversationConfig = ConversationConfig(
            systemMessage: Message(configuration.systemPrompt, role: .system),
            samplerConfig: samplerConfig,
            maxOutputTokens: outputTokenLimit(for: configuration)
        )
        return try await engine.createConversation(with: conversationConfig)
    }

    private func generateAnalyticsOutput(
        events: [StoryEvent],
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        let prompt = LocalModelLibrary.analyticsUserPrompt(
            for: events,
            configuration: configuration,
            eventLimit: Self.primaryAnalyticsEventLimit
        )

        do {
            return try await sendAnalyticsPrompt(prompt, configuration: configuration)
        } catch {
            state = .generating("Retrying with a smaller dashboard prompt...")
            try await resetLiteRTLMConversation(configuration: configuration)
            let fallbackPrompt = LocalModelLibrary.analyticsUserPrompt(
                for: events,
                configuration: configuration,
                eventLimit: Self.fallbackAnalyticsEventLimit
            )
            return try await sendAnalyticsPrompt(fallbackPrompt, configuration: configuration)
        }
    }

    private func resetLiteRTLMConversation(configuration: LocalLLMConfiguration) async throws {
        guard let engine else {
            throw LocalLLMRuntimeSessionError.modelNotLoaded
        }

        try? conversation?.cancel()
        conversation = try await Self.makeConversation(engine: engine, configuration: configuration)
    }

    private static func sessionContextTokenBudget(for model: LocalLLMModel) -> Int {
        if model.id.contains("e4b") {
            return 3_072
        }

        if model.id.contains("1b") {
            return 2_048
        }

        return 4_096
    }

    private static func outputTokenLimit(for configuration: LocalLLMConfiguration) -> Int {
        min(max(configuration.maxTokens, 128), 512)
    }

    private func sendAnalyticsPrompt(
        _ prompt: String,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        guard let conversation else {
            throw LocalLLMRuntimeSessionError.modelNotLoaded
        }

        let response = try await conversation.sendMessage(Message(prompt))
        return response.toString
    }
    #else
    private func initializeLiteRTLM(
        modelURL: URL,
        installed: InstalledLocalLLMModel,
        configuration: LocalLLMConfiguration
    ) async throws {
        _ = modelURL
        _ = installed
        _ = configuration
        throw LocalLLMRuntimeSessionError.packageMissing
    }

    private func generateAnalyticsOutput(
        events: [StoryEvent],
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        _ = events
        _ = configuration
        throw LocalLLMRuntimeSessionError.packageMissing
    }

    private func sendAnalyticsPrompt(
        _ prompt: String,
        configuration: LocalLLMConfiguration
    ) async throws -> String {
        _ = prompt
        _ = configuration
        throw LocalLLMRuntimeSessionError.packageMissing
    }
    #endif
}
