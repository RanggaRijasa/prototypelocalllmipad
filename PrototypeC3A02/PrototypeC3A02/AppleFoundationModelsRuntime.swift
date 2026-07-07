//
//  AppleFoundationModelsRuntime.swift
//  PrototypeC3A02
//
//  Created by Codex on 07/07/26.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelsRuntime {
    static let displayName = "Apple Foundation Models"

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return AppleFoundationModelsBackend.isAvailable
        }
        #endif

        return false
    }

    static var readinessMessage: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return AppleFoundationModelsBackend.readinessMessage
        }
        #endif

        return "Apple Foundation Models require iOS 26 or later on a device that supports Apple Intelligence."
    }

    static func generateAnalytics(
        events: [StoryEvent],
        configuration: LocalLLMConfiguration
    ) async throws -> GeneratedLLMAnalyticsInsight {
        guard !events.isEmpty else {
            throw AppleFoundationModelsRuntimeError.noEvents
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return try await AppleFoundationModelsBackend.generateAnalytics(
                events: events,
                configuration: configuration
            )
        }
        #endif

        throw AppleFoundationModelsRuntimeError.unsupportedOS
    }
}

enum AppleFoundationModelsRuntimeError: LocalizedError {
    case unsupportedOS
    case unavailable(String)
    case noEvents
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            "Apple Foundation Models require iOS 26 or later on a device that supports Apple Intelligence."
        case .unavailable(let reason):
            "Apple Foundation Models are unavailable: \(reason)"
        case .noEvents:
            "There are no story events to analyze."
        case .generationFailed(let reason):
            "Apple Foundation Models generation failed: \(reason)"
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private enum AppleFoundationModelsBackend {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }

        return false
    }

    static var readinessMessage: String {
        availabilityMessage(for: SystemLanguageModel.default.availability)
    }

    static func generateAnalytics(
        events: [StoryEvent],
        configuration: LocalLLMConfiguration
    ) async throws -> GeneratedLLMAnalyticsInsight {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AppleFoundationModelsRuntimeError.unavailable(availabilityMessage(for: model.availability))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: configuration.systemPrompt
        )
        let prompt = await LocalModelLibrary.analyticsUserPrompt(
            for: events,
            configuration: configuration,
            eventLimit: 16
        )

        do {
            let response = try await session.respond(
                to: prompt,
                options: generationOptions(for: configuration)
            )
            return LocalLLMAnalyticsParser.parse(
                modelOutput: response.content,
                modelName: AppleFoundationModelsRuntime.displayName
            )
        } catch let error as LanguageModelSession.GenerationError {
            throw AppleFoundationModelsRuntimeError.generationFailed(
                error.localizedDescription
            )
        } catch {
            throw AppleFoundationModelsRuntimeError.generationFailed(
                error.localizedDescription
            )
        }
    }

    private static func generationOptions(for configuration: LocalLLMConfiguration) -> GenerationOptions {
        let maximumResponseTokens = min(max(configuration.maxTokens, 128), 512)
        let temperature = min(max(configuration.temperature, 0.0), 2.0)
        let topP = min(max(configuration.topP, 0.05), 1.0)
        let sampling: GenerationOptions.SamplingMode = temperature == 0
            ? .greedy
            : .random(probabilityThreshold: topP)

        return GenerationOptions(
            sampling: sampling,
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )
    }

    private static func availabilityMessage(
        for availability: SystemLanguageModel.Availability
    ) -> String {
        switch availability {
        case .available:
            "Available. The app will use Apple's on-device system language model."
        case .unavailable(.deviceNotEligible):
            "This device is not eligible for Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Apple Intelligence is not enabled in Settings."
        case .unavailable(.modelNotReady):
            "The system model is still downloading or preparing."
        @unknown default:
            "The system language model is unavailable for an unknown reason."
        }
    }
}
#endif
