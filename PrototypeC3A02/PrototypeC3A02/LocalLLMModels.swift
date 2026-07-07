//
//  LocalLLMModels.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import Combine
import Foundation

enum LocalLLMRuntime: String, Codable, CaseIterable, Identifiable {
    case mediaPipeTask
    case liteRTLM
    case mlcLLM
    case coreML

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mediaPipeTask: "LiteRT .task"
        case .liteRTLM: "LiteRT-LM"
        case .mlcLLM: "MLC LLM"
        case .coreML: "Core ML"
        }
    }
}

enum LocalLLMAccelerator: String, Codable, CaseIterable, Identifiable {
    case cpu
    case gpu

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

struct LocalLLMConfiguration: Codable, Equatable {
    var maxTokens: Int
    var topK: Int
    var topP: Double
    var temperature: Double
    var accelerator: LocalLLMAccelerator
    var enableThinking: Bool
    var enableSpeculativeDecoding: Bool
    var systemPrompt: String
    var contextNotes: String

    static let defaultSystemPrompt = """
    You are an on-device storytelling analytics engine inside a family journaling app.
    Analyze parent-logged child story events and produce dashboard-ready insight only.
    Do not chat with the parent. Do not diagnose, label, or make medical claims.
    Prefer concrete patterns from the supplied rows over generic parenting advice.

    Return compact JSON only, with these exact keys:
    {
      "summary": "One concise paragraph explaining the most useful weekly pattern.",
      "commonTriggers": [
        {
          "title": "One short trigger label, such as Nighttime, Hunger, Homework, Drop-off, or Transition.",
          "explanation": "A grounded explanation of why this may trigger the child, using only the supplied rows."
        }
      ],
      "notablePatterns": ["Three grounded patterns, each tied to scene, place, mood, or time."],
      "parentReflectionPrompt": "One gentle non-diagnostic question for the parent.",
      "ethicalNote": "A short privacy and non-diagnosis reminder."
    }
    """

    static let defaultContextNotes = """
    Child profile: Leo, age 4.
    Data fields: date, scene, place, activity, mood, reason, and parent note.
    Dashboard goal: explain mood patterns, common triggers, and context comparison visualizations.
    Output style: structured analytics for charts and reflective summaries, not a chatbot reply.
    """

    static let `default` = LocalLLMConfiguration(
        maxTokens: 1024,
        topK: 40,
        topP: 0.95,
        temperature: 0.7,
        accelerator: .gpu,
        enableThinking: false,
        enableSpeculativeDecoding: false,
        systemPrompt: defaultSystemPrompt,
        contextNotes: defaultContextNotes
    )
}

struct LocalLLMFile: Codable, Hashable, Identifiable {
    let relativePath: String
    let urlString: String
    let sizeInBytes: Int64?

    var id: String { relativePath }

    var fileName: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var url: URL? {
        URL(string: urlString)
    }
}

struct LocalLLMModel: Codable, Identifiable {
    let id: String
    var name: String
    var provider: String
    var modelID: String
    var runtime: LocalLLMRuntime
    var description: String
    var version: String
    var sizeInBytes: Int64?
    var estimatedPeakMemoryInBytes: Int64?
    var supportsImages: Bool
    var isRecommended: Bool
    var files: [LocalLLMFile]
    var defaultConfiguration: LocalLLMConfiguration
}

struct InstalledLocalLLMModel: Codable, Identifiable {
    let id: String
    var model: LocalLLMModel
    var localDirectoryPath: String
    var installedAt: Date
    var downloadedBytes: Int64
}

struct GeneratedLLMCommonTrigger: Codable, Equatable, Identifiable {
    var title: String
    var explanation: String

    var id: String { title }

    init(title: String, explanation: String) {
        self.title = title
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            title = try container.decodeFirstPresentString(forKeys: [.title, .trigger, .label, .name]) ?? "Trigger"
            explanation = try container.decodeFirstPresentString(forKeys: [.explanation, .reason, .description, .details]) ?? ""
            return
        }

        let container = try decoder.singleValueContainer()
        title = try container.decode(String.self)
        explanation = "This trigger appeared in the generated model output, but no explanation was provided."
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(explanation, forKey: .explanation)
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case trigger
        case label
        case name
        case explanation
        case reason
        case description
        case details
    }
}

struct GeneratedLLMAnalyticsInsight: Codable, Equatable, Identifiable {
    var id: UUID
    var modelName: String
    var generatedAt: Date
    var summary: String
    var commonTriggers: [GeneratedLLMCommonTrigger]
    var notablePatterns: [String]
    var parentReflectionPrompt: String
    var ethicalNote: String

    init(
        id: UUID = UUID(),
        modelName: String,
        generatedAt: Date = Date(),
        summary: String,
        commonTriggers: [GeneratedLLMCommonTrigger],
        notablePatterns: [String],
        parentReflectionPrompt: String,
        ethicalNote: String
    ) {
        self.id = id
        self.modelName = modelName
        self.generatedAt = generatedAt
        self.summary = summary
        self.commonTriggers = commonTriggers
        self.notablePatterns = notablePatterns
        self.parentReflectionPrompt = parentReflectionPrompt
        self.ethicalNote = ethicalNote
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case modelName
        case generatedAt
        case summary
        case commonTriggers
        case notablePatterns
        case parentReflectionPrompt
        case ethicalNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName) ?? "Local LLM"
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        commonTriggers = try container.decodeIfPresent([GeneratedLLMCommonTrigger].self, forKey: .commonTriggers) ?? []
        notablePatterns = try container.decodeIfPresent([String].self, forKey: .notablePatterns) ?? []
        parentReflectionPrompt = try container.decodeIfPresent(String.self, forKey: .parentReflectionPrompt) ?? ""
        ethicalNote = try container.decodeIfPresent(String.self, forKey: .ethicalNote) ?? ""
    }
}

enum LocalLLMAnalyticsParser {
    static func parse(modelOutput: String, modelName: String) -> GeneratedLLMAnalyticsInsight {
        let jsonString = extractJSONObject(from: modelOutput)
        if let data = jsonString.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return GeneratedLLMAnalyticsInsight(
                modelName: modelName,
                summary: payload.summary,
                commonTriggers: payload.commonTriggers,
                notablePatterns: payload.notablePatterns,
                parentReflectionPrompt: payload.parentReflectionPrompt,
                ethicalNote: payload.ethicalNote
            )
        }

        return GeneratedLLMAnalyticsInsight(
            modelName: modelName,
            summary: modelOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            commonTriggers: [],
            notablePatterns: [],
            parentReflectionPrompt: "What pattern feels most useful to watch over the next few days?",
            ethicalNote: "Model output is reflective and non-diagnostic."
        )
    }

    static func repairFallbackInsight(_ insight: GeneratedLLMAnalyticsInsight) -> GeneratedLLMAnalyticsInsight {
        guard insight.commonTriggers.isEmpty,
              insight.notablePatterns.isEmpty,
              looksLikeRawJSON(insight.summary) else {
            return insight
        }

        let repaired = parse(modelOutput: insight.summary, modelName: insight.modelName)
        guard repaired.summary != insight.summary
            || !repaired.commonTriggers.isEmpty
            || !repaired.notablePatterns.isEmpty else {
            return insight
        }

        return GeneratedLLMAnalyticsInsight(
            id: insight.id,
            modelName: insight.modelName,
            generatedAt: insight.generatedAt,
            summary: repaired.summary,
            commonTriggers: repaired.commonTriggers,
            notablePatterns: repaired.notablePatterns,
            parentReflectionPrompt: repaired.parentReflectionPrompt,
            ethicalNote: repaired.ethicalNote
        )
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return trimmed
        }

        return String(trimmed[start...end])
    }

    private static func looksLikeRawJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{")
            || trimmed.hasPrefix("```")
            || (trimmed.contains("\"summary\"") && trimmed.contains("\"commonTriggers\""))
    }

    private struct Payload: Decodable {
        let summary: String
        let commonTriggers: [GeneratedLLMCommonTrigger]
        let notablePatterns: [String]
        let parentReflectionPrompt: String
        let ethicalNote: String

        private enum CodingKeys: String, CodingKey {
            case summary
            case commonTriggers
            case notablePatterns
            case parentReflectionPrompt
            case ethicalNote
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
            commonTriggers = try container.decodeIfPresent([GeneratedLLMCommonTrigger].self, forKey: .commonTriggers) ?? []
            notablePatterns = try container.decodeFlexibleStringArray(forKey: .notablePatterns)
            parentReflectionPrompt = try container.decodeIfPresent(String.self, forKey: .parentReflectionPrompt) ?? ""
            ethicalNote = try container.decodeIfPresent(String.self, forKey: .ethicalNote) ?? ""
        }
    }

    fileprivate struct FlexibleInsightText: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let text = try? container.decode(String.self) {
                value = text
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            let title = try container.decodeFirstPresentString(forKeys: [.title, .pattern, .label, .name])
            let explanation = try container.decodeFirstPresentString(forKeys: [.explanation, .description, .details, .text, .summary])

            switch (title?.trimmingCharacters(in: .whitespacesAndNewlines), explanation?.trimmingCharacters(in: .whitespacesAndNewlines)) {
            case let (.some(title), .some(explanation)) where !title.isEmpty && !explanation.isEmpty:
                value = "\(title): \(explanation)"
            case let (.some(title), _) where !title.isEmpty:
                value = title
            case let (_, .some(explanation)) where !explanation.isEmpty:
                value = explanation
            default:
                value = ""
            }
        }

        private enum CodingKeys: String, CodingKey {
            case title
            case pattern
            case label
            case name
            case explanation
            case description
            case details
            case text
            case summary
        }
    }
}

private extension KeyedDecodingContainer where Key: CodingKey {
    func decodeFirstPresentString(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringArray(forKey key: Key) throws -> [String] {
        if let strings = try? decodeIfPresent([String].self, forKey: key) {
            return strings
        }

        if let items = try? decodeIfPresent([LocalLLMAnalyticsParser.FlexibleInsightText].self, forKey: key) {
            return items
                .map(\.value)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        return []
    }
}

struct LocalLLMDownloadProgress: Equatable {
    var modelID: String
    var fileName: String
    var completedFiles: Int
    var totalFiles: Int
    var completedBytes: Int64
    var totalBytes: Int64?
    var isDownloading: Bool
    var message: String

    var fractionCompleted: Double? {
        if let totalBytes, totalBytes > 0 {
            return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
        }

        guard totalFiles > 0 else { return nil }
        return Double(completedFiles) / Double(totalFiles)
    }
}

enum LocalLLMModelImportError: LocalizedError {
    case missingURL
    case invalidURL(String)
    case noSupportedFiles(String)

    var errorDescription: String? {
        switch self {
        case .missingURL:
            "Paste at least one Hugging Face model file URL."
        case .invalidURL(let value):
            "Invalid URL: \(value)"
        case .noSupportedFiles(let repoID):
            "No supported model files found in \(repoID)."
        }
    }
}

enum LocalModelCatalog {
    static let recommended: [LocalLLMModel] = [
        recommendedLiteRTLMModel(
            id: "gemma-4-e2b-it-litertlm",
            name: "Gemma-4-E2B-it",
            provider: "LiteRT Community",
            modelID: "litert-community/gemma-4-E2B-it-litert-lm",
            modelFile: "gemma-4-E2B-it.litertlm",
            revision: "7fa1d78473894f7e736a21d920c3aa80f950c0db",
            description: "Gemma 4 E2B LiteRT-LM package from the AI Edge Gallery allowlist. Best first choice for newer iPhones with 8 GB or more RAM.",
            sizeInBytes: 2_583_085_056,
            estimatedPeakMemoryInBytes: 8_589_934_592,
            supportsImages: true,
            isRecommended: true,
            maxTokens: 1_024,
            enableThinking: false,
            enableSpeculativeDecoding: false
        ),
        recommendedLiteRTLMModel(
            id: "gemma-4-e4b-it-litertlm",
            name: "Gemma-4-E4B-it",
            provider: "LiteRT Community",
            modelID: "litert-community/gemma-4-E4B-it-litert-lm",
            modelFile: "gemma-4-E4B-it.litertlm",
            revision: "9695417f248178c63a9f318c6e0c56cb917cb837",
            description: "Larger Gemma 4 E4B LiteRT-LM package for devices with roughly 12 GB or more RAM.",
            sizeInBytes: 3_654_467_584,
            estimatedPeakMemoryInBytes: 12_884_901_888,
            supportsImages: true,
            isRecommended: false,
            maxTokens: 1_024,
            enableThinking: false,
            enableSpeculativeDecoding: false
        ),
        recommendedLiteRTLMModel(
            id: "gemma-3n-e2b-it-litertlm",
            name: "Gemma-3n-E2B-it",
            provider: "Google",
            modelID: "google/gemma-3n-E2B-it-litert-lm",
            modelFile: "gemma-3n-E2B-it-int4.litertlm",
            revision: "ba9ca88da013b537b6ed38108be609b8db1c3a16",
            description: "Gemma 3n E2B LiteRT-LM fallback with text, vision, and audio support.",
            sizeInBytes: 3_655_827_456,
            estimatedPeakMemoryInBytes: 8_589_934_592,
            supportsImages: true,
            isRecommended: false,
            maxTokens: 4_096,
            enableThinking: false,
            enableSpeculativeDecoding: false
        ),
        recommendedLiteRTLMModel(
            id: "gemma-3n-e4b-it-litertlm",
            name: "Gemma-3n-E4B-it",
            provider: "Google",
            modelID: "google/gemma-3n-E4B-it-litert-lm",
            modelFile: "gemma-3n-E4B-it-int4.litertlm",
            revision: "297ed75955702dec3503e00c2c2ecbbf475300bc",
            description: "Larger Gemma 3n E4B LiteRT-LM fallback for high-memory devices.",
            sizeInBytes: 4_919_541_760,
            estimatedPeakMemoryInBytes: 12_884_901_888,
            supportsImages: true,
            isRecommended: false,
            maxTokens: 4_096,
            enableThinking: false,
            enableSpeculativeDecoding: false
        ),
        recommendedLiteRTLMModel(
            id: "gemma3-1b-it-litertlm",
            name: "Gemma3-1B-IT",
            provider: "LiteRT Community",
            modelID: "litert-community/Gemma3-1B-IT",
            modelFile: "gemma3-1b-it-int4.litertlm",
            revision: "42d538a932e8d5b12e6b3b455f5572560bd60b2c",
            description: "Small LiteRT-LM model for quick local testing before downloading a larger Gemma 4 model.",
            sizeInBytes: 584_417_280,
            estimatedPeakMemoryInBytes: 6_442_450_944,
            supportsImages: false,
            isRecommended: true,
            maxTokens: 1_024,
            enableThinking: false,
            enableSpeculativeDecoding: false
        ),
        recommendedLiteRTLMModel(
            id: "qwen25-15b-instruct-litertlm",
            name: "Qwen2.5-1.5B-Instruct",
            provider: "LiteRT Community",
            modelID: "litert-community/Qwen2.5-1.5B-Instruct",
            modelFile: "Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm",
            revision: "19edb84c69a0212f29a6ef17ba0d6f278b6a1614",
            description: "Non-Gemma LiteRT-LM baseline with a smaller download and conservative sampling defaults.",
            sizeInBytes: 1_597_931_520,
            estimatedPeakMemoryInBytes: 6_442_450_944,
            supportsImages: false,
            isRecommended: false,
            maxTokens: 4_096,
            topK: 20,
            topP: 0.8,
            temperature: 0.7,
            enableThinking: false,
            enableSpeculativeDecoding: false
        )
    ]

    private static func recommendedLiteRTLMModel(
        id: String,
        name: String,
        provider: String,
        modelID: String,
        modelFile: String,
        revision: String,
        description: String,
        sizeInBytes: Int64,
        estimatedPeakMemoryInBytes: Int64,
        supportsImages: Bool,
        isRecommended: Bool,
        maxTokens: Int,
        topK: Int = 40,
        topP: Double = 0.95,
        temperature: Double = 0.7,
        enableThinking: Bool,
        enableSpeculativeDecoding: Bool
    ) -> LocalLLMModel {
        LocalLLMModel(
            id: id,
            name: name,
            provider: provider,
            modelID: modelID,
            runtime: .liteRTLM,
            description: description,
            version: "AI Edge Gallery 1.0.15",
            sizeInBytes: sizeInBytes,
            estimatedPeakMemoryInBytes: estimatedPeakMemoryInBytes,
            supportsImages: supportsImages,
            isRecommended: isRecommended,
            files: [
                LocalLLMFile(
                    relativePath: modelFile,
                    urlString: "https://huggingface.co/\(modelID)/resolve/\(revision)/\(modelFile)",
                    sizeInBytes: sizeInBytes
                )
            ],
            defaultConfiguration: LocalLLMConfiguration(
                maxTokens: maxTokens,
                topK: topK,
                topP: topP,
                temperature: temperature,
                accelerator: .gpu,
                enableThinking: enableThinking,
                enableSpeculativeDecoding: enableSpeculativeDecoding,
                systemPrompt: LocalLLMConfiguration.defaultSystemPrompt,
                contextNotes: LocalLLMConfiguration.defaultContextNotes
            )
        )
    }

    static func importedModel(name: String, urlsText: String, runtime: LocalLLMRuntime) async throws -> LocalLLMModel {
        let urlStrings = tokenizedURLs(from: urlsText)
        guard urlStrings.count == 1, let url = URL(string: urlStrings[0]),
              let repoID = huggingFaceModelID(from: url),
              !url.pathComponents.contains("resolve") else {
            return try customModel(name: name, urlsText: urlsText, runtime: runtime)
        }

        return try await resolveHuggingFaceRepository(repoID: repoID, name: name, runtime: runtime)
    }

    static func customModel(name: String, urlsText: String, runtime: LocalLLMRuntime) throws -> LocalLLMModel {
        let urlStrings = tokenizedURLs(from: urlsText)
        guard !urlStrings.isEmpty else { throw LocalLLMModelImportError.missingURL }

        let urls = try urlStrings.map { value in
            guard let url = URL(string: value), let scheme = url.scheme, scheme.hasPrefix("http") else {
                throw LocalLLMModelImportError.invalidURL(value)
            }
            return url
        }

        return makeImportedModel(name: name, urls: urls, runtime: runtime)
    }

    private static func resolveHuggingFaceRepository(
        repoID: String,
        name: String,
        runtime: LocalLLMRuntime
    ) async throws -> LocalLLMModel {
        let encodedRepoID = repoID
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        guard let apiURL = URL(string: "https://huggingface.co/api/models/\(encodedRepoID)") else {
            throw LocalLLMModelImportError.invalidURL(repoID)
        }

        let (data, response) = try await URLSession.shared.data(from: apiURL)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let info = try JSONDecoder().decode(HuggingFaceModelInfo.self, from: data)
        let supportedFiles = info.siblings
            .filter { isSupportedModelFile($0.rfilename) }
            .sorted { fileSortRank($0.rfilename) < fileSortRank($1.rfilename) }

        guard !supportedFiles.isEmpty else {
            throw LocalLLMModelImportError.noSupportedFiles(repoID)
        }

        let urls = supportedFiles.compactMap { file in
            URL(string: "https://huggingface.co/\(encodedRepoID)/resolve/main/\(encodedPath(file.rfilename))")
        }

        return makeImportedModel(name: name, urls: urls, runtime: runtime, fileSizes: supportedFiles.map(\.size))
    }

    private static func makeImportedModel(
        name: String,
        urls: [URL],
        runtime: LocalLLMRuntime,
        fileSizes: [Int64?]? = nil
    ) -> LocalLLMModel {
        let urlStrings = urls.map(\.absoluteString)
        let modelID = huggingFaceModelID(from: urls.first) ?? urls.first?.host ?? "custom-model"
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? inferredDisplayName(from: modelID, fallbackURL: urls.first)
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sizes = fileSizes ?? Array(repeating: nil, count: urls.count)

        return LocalLLMModel(
            id: stableID(from: "\(modelID)-\(urlStrings.joined(separator: "-"))"),
            name: displayName,
            provider: "Imported",
            modelID: modelID,
            runtime: runtime,
            description: "Imported model file set.",
            version: "Custom",
            sizeInBytes: sizes.compactMap { $0 }.isEmpty ? nil : sizes.compactMap { $0 }.reduce(0, +),
            estimatedPeakMemoryInBytes: nil,
            supportsImages: false,
            isRecommended: false,
            files: zip(urls, sizes).map { url, size in
                LocalLLMFile(relativePath: relativePath(from: url), urlString: url.absoluteString, sizeInBytes: size)
            },
            defaultConfiguration: LocalLLMConfiguration.default
        )
    }

    private static func tokenizedURLs(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func isSupportedModelFile(_ path: String) -> Bool {
        path == "model.yaml"
            || path.hasPrefix("checkpoints/")
            || path.hasSuffix(".task")
            || path.hasSuffix(".litertlm")
            || path.hasSuffix(".mlmodel")
            || path.hasSuffix(".mlpackage")
    }

    private static func fileSortRank(_ path: String) -> String {
        if path == "model.yaml" { return "0-\(path)" }
        if path.hasSuffix(".task") || path.hasSuffix(".litertlm") { return "1-\(path)" }
        return "2-\(path)"
    }

    private static func encodedPath(_ path: String) -> String {
        path
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    private struct HuggingFaceModelInfo: Decodable {
        let siblings: [Sibling]

        struct Sibling: Decodable {
            let rfilename: String
            let size: Int64?
        }
    }

    private static func huggingFaceModelID(from url: URL?) -> String? {
        guard let url, url.host?.contains("huggingface.co") == true else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])/\(parts[1])"
    }

    private static func inferredDisplayName(from modelID: String, fallbackURL: URL?) -> String {
        let lastModelComponent = modelID.split(separator: "/").last.map(String.init)
        return lastModelComponent ?? fallbackURL?.deletingPathExtension().lastPathComponent ?? "Imported Model"
    }

    private static func relativePath(from url: URL) -> String {
        let parts = url.pathComponents.filter { $0 != "/" }
        if let resolveIndex = parts.firstIndex(of: "resolve"), parts.count > resolveIndex + 2 {
            return parts[(resolveIndex + 2)...].joined(separator: "/")
        }

        return url.lastPathComponent.isEmpty ? "model.file" : url.lastPathComponent
    }

    private static func stableID(from value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars).replacingOccurrences(of: "--", with: "-")
    }
}

@MainActor
final class LocalModelLibrary: ObservableObject {
    static let generatedInsightUserDefaultsKey = "localLLMGeneratedInsight"
    static let installedModelsKey = "localLLMInstalledModels"
    static let customModelsKey = "localLLMCustomModels"
    static let selectedModelIDKey = "localLLMSelectedModelID"
    static let configurationKey = "localLLMConfiguration"

    @Published private(set) var installedModels: [InstalledLocalLLMModel] = []
    @Published private(set) var customModels: [LocalLLMModel] = []
    @Published private(set) var generatedInsight: GeneratedLLMAnalyticsInsight?
    @Published var selectedModelID: String? {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelIDKey) }
    }
    @Published var configuration: LocalLLMConfiguration {
        didSet { saveConfiguration() }
    }
    @Published var downloadProgress: LocalLLMDownloadProgress?
    @Published var lastMessage: String?

    init() {
        let savedInstalledModels = Self.load([InstalledLocalLLMModel].self, key: Self.installedModelsKey) ?? []
        let repairedInstalledModels = savedInstalledModels.map(Self.repairedInstalledModel)
        self.installedModels = repairedInstalledModels
        self.customModels = Self.load([LocalLLMModel].self, key: Self.customModelsKey) ?? []
        let savedGeneratedInsight = Self.load(
            GeneratedLLMAnalyticsInsight.self,
            key: Self.generatedInsightUserDefaultsKey
        )
        let repairedGeneratedInsight = savedGeneratedInsight.map(LocalLLMAnalyticsParser.repairFallbackInsight)
        self.generatedInsight = repairedGeneratedInsight
        self.selectedModelID = UserDefaults.standard.string(forKey: Self.selectedModelIDKey)
        let savedConfiguration = Self.load(LocalLLMConfiguration.self, key: Self.configurationKey) ?? .default
        self.configuration = Self.sanitizedConfiguration(savedConfiguration)

        if savedInstalledModels.map(\.localDirectoryPath) != repairedInstalledModels.map(\.localDirectoryPath)
            || savedInstalledModels.map(\.model.defaultConfiguration) != repairedInstalledModels.map(\.model.defaultConfiguration) {
            Self.save(repairedInstalledModels, key: Self.installedModelsKey)
        }

        if savedConfiguration != configuration {
            Self.save(configuration, key: Self.configurationKey)
        }

        if savedGeneratedInsight != repairedGeneratedInsight, let repairedGeneratedInsight {
            Self.save(repairedGeneratedInsight, key: Self.generatedInsightUserDefaultsKey)
        }

        repairCompletedDownloads(showMessage: false)
    }

    var availableModels: [LocalLLMModel] {
        LocalModelCatalog.recommended + customModels
    }

    var selectedInstalledModel: InstalledLocalLLMModel? {
        guard let selectedModelID else { return nil }
        return installedModels.first { $0.id == selectedModelID }
    }

    func isInstalled(_ model: LocalLLMModel) -> Bool {
        installedModels.contains { $0.id == model.id }
    }

    func installStatus(for model: LocalLLMModel) -> String {
        if let installed = installedModels.first(where: { $0.id == model.id }) {
            return "Ready • \(Self.formattedBytes(installed.downloadedBytes))"
        }

        if let partialBytes = partialDownloadBytes(for: model) {
            return "Partial • \(Self.formattedBytes(partialBytes))"
        }

        return Self.formattedBytes(model.sizeInBytes)
    }

    func repairCompletedDownloads(showMessage: Bool = true) {
        var repairedModels: [String] = []
        for model in availableModels where !isInstalled(model) {
            let shouldSelect = selectedInstalledModel == nil || selectedModelID == model.id
            if finalizeCompletedPartialDownload(for: model, shouldSelect: shouldSelect, updateMessage: false) {
                repairedModels.append(model.name)
            }
        }

        if showMessage, let firstModelName = repairedModels.first {
            lastMessage = repairedModels.count == 1
                ? "\(firstModelName) is ready"
                : "Finished installing \(repairedModels.count) downloaded models"
        }
    }

    func addCustomModel(_ model: LocalLLMModel) {
        customModels.removeAll { $0.id == model.id }
        customModels.insert(model, at: 0)
        saveCustomModels()
        lastMessage = "Imported \(model.name)"
    }

    func select(_ model: LocalLLMModel) {
        selectedModelID = model.id
        configuration = Self.sanitizedConfiguration(model.defaultConfiguration)
        lastMessage = "\(model.name) selected"
    }

    func updateConfiguration(_ newValue: LocalLLMConfiguration) {
        configuration = newValue
        lastMessage = "Configuration saved"
    }

    func saveGeneratedInsight(_ insight: GeneratedLLMAnalyticsInsight) {
        generatedInsight = insight
        Self.save(insight, key: Self.generatedInsightUserDefaultsKey)
        lastMessage = "Generated analytics insight with \(insight.modelName)"
    }

    func clearGeneratedInsight() {
        generatedInsight = nil
        UserDefaults.standard.removeObject(forKey: Self.generatedInsightUserDefaultsKey)
        lastMessage = "Generated analytics insight cleared"
    }

    func download(_ model: LocalLLMModel) async {
        guard !model.files.isEmpty else {
            lastMessage = "No files configured for \(model.name)"
            return
        }

        if finalizeCompletedPartialDownload(for: model) {
            return
        }

        let totalBytes = model.files.compactMap(\.sizeInBytes).reduce(Int64(0), +)
        let knownTotal = totalBytes > 0 ? totalBytes : nil
        var completedBytes: Int64 = 0
        let modelDirectory = Self.modelStorageDirectory(for: model)

        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

            for (index, file) in model.files.enumerated() {
                guard let url = file.url else { throw LocalLLMModelImportError.invalidURL(file.urlString) }

                downloadProgress = LocalLLMDownloadProgress(
                    modelID: model.id,
                    fileName: file.fileName,
                    completedFiles: index,
                    totalFiles: model.files.count,
                    completedBytes: completedBytes,
                    totalBytes: knownTotal,
                    isDownloading: true,
                    message: "Downloading \(file.fileName)"
                )

                let bytes = try await download(
                    file: file,
                    from: url,
                    into: modelDirectory,
                    modelID: model.id,
                    completedFiles: index,
                    totalFiles: model.files.count,
                    completedBytesBeforeFile: completedBytes,
                    knownTotalBytes: knownTotal
                )
                completedBytes += bytes
            }

            markInstalled(model, modelDirectory: modelDirectory, downloadedBytes: completedBytes, shouldSelect: true)

            downloadProgress = LocalLLMDownloadProgress(
                modelID: model.id,
                fileName: "",
                completedFiles: model.files.count,
                totalFiles: model.files.count,
                completedBytes: completedBytes,
                totalBytes: knownTotal,
                isDownloading: false,
                message: "Downloaded \(model.name)"
            )
            lastMessage = "\(model.name) is ready"
        } catch {
            downloadProgress = nil
            lastMessage = "Download failed: \(error.localizedDescription)"
        }
    }

    func analyticsPrompt(for events: [StoryEvent]) -> String {
        Self.analyticsPrompt(for: events, configuration: configuration)
    }

    static func analyticsPrompt(for events: [StoryEvent], configuration: LocalLLMConfiguration) -> String {
        """
        System:
        \(configuration.systemPrompt)

        \(analyticsUserPrompt(for: events, configuration: configuration))
        """
    }

    static func analyticsUserPrompt(
        for events: [StoryEvent],
        configuration: LocalLLMConfiguration,
        eventLimit: Int = 24
    ) -> String {
        let clampedLimit = max(1, eventLimit)
        let latestEvents = events.sorted { $0.date > $1.date }.prefix(clampedLimit)
        let eventLines = latestEvents.map { event in
            "- \(event.date.formatted(date: .abbreviated, time: .shortened)) | scene: \(event.scene.displayName) | place: \(event.place.displayName) | activity: \(event.activity) | mood: \(event.mood.displayName) | reason: \(event.reason ?? "None") | note: \(event.parentNote ?? "None")"
        }
        .joined(separator: "\n")

        return """
        Context:
        \(configuration.contextNotes)

        Recent story events, newest first:
        \(eventLines.isEmpty ? "No story events yet." : eventLines)

        Task:
        Analyze these rows for a dashboard. Return JSON only using the schema from the system prompt.
        Return bare JSON without markdown fences. `commonTriggers` must be objects with title and explanation. `notablePatterns` must be plain strings, not objects.
        Keep the response compact, complete, and under \(min(max(configuration.maxTokens, 128), 512)) output tokens.
        """
    }

    func runtimeReadinessMessage() -> String {
        guard let selectedInstalledModel else {
            return "Download or select a local model first."
        }

        switch selectedInstalledModel.model.runtime {
        case .liteRTLM:
            return "LiteRT-LM model files are installed. Load the model into memory before generating analytics."
        case .mediaPipeTask, .mlcLLM:
            return "Model files are installed, but this prototype only runs LiteRT-LM models directly."
        case .coreML:
            return "Core ML model files are installed. Add a compatible decoder pipeline to enable generation."
        }
    }

    private func download(
        file: LocalLLMFile,
        from url: URL,
        into modelDirectory: URL,
        modelID: String,
        completedFiles: Int,
        totalFiles: Int,
        completedBytesBeforeFile: Int64,
        knownTotalBytes: Int64?
    ) async throws -> Int64 {
        let destination = modelDirectory.appendingPathComponent(file.relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let downloader = LocalLLMFileDownloader(
            destinationURL: destination,
            expectedFileBytes: file.sizeInBytes
        ) { [weak self] fileBytes, expectedFileBytes in
            Task { @MainActor [weak self] in
                let completedBytes = completedBytesBeforeFile + fileBytes
                let totalBytes = knownTotalBytes ?? expectedFileBytes.map { completedBytesBeforeFile + $0 }
                let message: String
                if let expectedFileBytes {
                    message = "Downloading \(file.fileName) \(Self.formattedBytes(fileBytes)) of \(Self.formattedBytes(expectedFileBytes))"
                } else {
                    message = "Downloading \(file.fileName) \(Self.formattedBytes(fileBytes))"
                }

                self?.downloadProgress = LocalLLMDownloadProgress(
                    modelID: modelID,
                    fileName: file.fileName,
                    completedFiles: completedFiles,
                    totalFiles: totalFiles,
                    completedBytes: completedBytes,
                    totalBytes: totalBytes,
                    isDownloading: true,
                    message: message
                )
            }
        }
        return try await downloader.download(from: url)
    }

    static func modelStorageDirectory(for model: LocalLLMModel) -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalLLMModels", isDirectory: true)
        return root.appendingPathComponent(model.id, isDirectory: true)
    }

    private static func repairedInstalledModel(_ installed: InstalledLocalLLMModel) -> InstalledLocalLLMModel {
        var repaired = installed
        if let catalogModel = LocalModelCatalog.recommended.first(where: { $0.id == installed.model.id }) {
            repaired.model = catalogModel
        }
        repaired.localDirectoryPath = modelStorageDirectory(for: repaired.model).path
        return repaired
    }

    private static func sanitizedConfiguration(_ configuration: LocalLLMConfiguration) -> LocalLLMConfiguration {
        var sanitized = configuration
        if sanitized.maxTokens > 2_048 {
            sanitized.maxTokens = 1_024
            sanitized.enableThinking = false
            sanitized.enableSpeculativeDecoding = false
        }
        if sanitized.systemPrompt.contains("\"dashboardFocus\"")
            || sanitized.systemPrompt.contains("\"chartSuggestions\"")
            || !sanitized.systemPrompt.contains("\"commonTriggers\"") {
            sanitized.systemPrompt = LocalLLMConfiguration.defaultSystemPrompt
        }
        return sanitized
    }

    private func partialDownloadBytes(for model: LocalLLMModel) -> Int64? {
        let modelDirectory = Self.modelStorageDirectory(for: model)
        let partialBytes = model.files.reduce(Int64(0)) { total, file in
            let destination = modelDirectory.appendingPathComponent(file.relativePath)
            let partialURL = LocalLLMFileDownloader.partialURL(for: destination)
            return total + (Self.fileSize(at: partialURL) ?? 0)
        }
        return partialBytes > 0 ? partialBytes : nil
    }

    @discardableResult
    private func finalizeCompletedPartialDownload(
        for model: LocalLLMModel,
        shouldSelect: Bool = true,
        updateMessage: Bool = true
    ) -> Bool {
        let modelDirectory = Self.modelStorageDirectory(for: model)
        var downloadedBytes: Int64 = 0

        do {
            for file in model.files {
                let destination = modelDirectory.appendingPathComponent(file.relativePath)
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if let finalBytes = Self.fileSize(at: destination),
                   file.sizeInBytes == nil || finalBytes >= (file.sizeInBytes ?? 0) {
                    downloadedBytes += finalBytes
                    continue
                }

                guard let expectedBytes = file.sizeInBytes else {
                    return false
                }

                let partialURL = LocalLLMFileDownloader.partialURL(for: destination)
                guard let partialBytes = Self.fileSize(at: partialURL), partialBytes >= expectedBytes else {
                    return false
                }

                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: partialURL, to: destination)
                downloadedBytes += partialBytes
            }

            markInstalled(
                model,
                modelDirectory: modelDirectory,
                downloadedBytes: downloadedBytes,
                shouldSelect: shouldSelect
            )

            if updateMessage {
                downloadProgress = LocalLLMDownloadProgress(
                    modelID: model.id,
                    fileName: "",
                    completedFiles: model.files.count,
                    totalFiles: model.files.count,
                    completedBytes: downloadedBytes,
                    totalBytes: model.sizeInBytes,
                    isDownloading: false,
                    message: "Downloaded \(model.name)"
                )
                lastMessage = "\(model.name) is ready"
            }

            return true
        } catch {
            if updateMessage {
                lastMessage = "Could not finish installing \(model.name): \(error.localizedDescription)"
            }
            return false
        }
    }

    private func markInstalled(
        _ model: LocalLLMModel,
        modelDirectory: URL,
        downloadedBytes: Int64,
        shouldSelect: Bool
    ) {
        let installed = InstalledLocalLLMModel(
            id: model.id,
            model: model,
            localDirectoryPath: modelDirectory.path,
            installedAt: Date(),
            downloadedBytes: downloadedBytes
        )

        installedModels.removeAll { $0.id == model.id }
        installedModels.insert(installed, at: 0)
        if shouldSelect {
            selectedModelID = model.id
            configuration = Self.sanitizedConfiguration(model.defaultConfiguration)
        }
        saveInstalledModels()
    }

    private func saveInstalledModels() {
        Self.save(installedModels, key: Self.installedModelsKey)
    }

    private func saveCustomModels() {
        Self.save(customModels, key: Self.customModelsKey)
    }

    private func saveConfiguration() {
        Self.save(configuration, key: Self.configurationKey)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func formattedBytes(_ value: Int64?) -> String {
        guard let value else { return "Size unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: value)
    }

    private static func fileSize(at url: URL) -> Int64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int64
        return size.map { $0 > 0 ? $0 : nil } ?? nil
    }
}

private final class LocalLLMFileDownloader: NSObject, URLSessionDataDelegate {
    private let destinationURL: URL
    private let expectedFileBytes: Int64?
    private let progressHandler: (Int64, Int64?) -> Void
    private var continuation: CheckedContinuation<Int64, Error>?
    private var fileHandle: FileHandle?
    private var session: URLSession?
    private var resumeOffset: Int64 = 0
    private var bytesWrittenThisRequest: Int64 = 0
    private var expectedTotalBytes: Int64?
    private var terminalError: Error?
    private var partialAlreadyComplete = false
    private let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    init(
        destinationURL: URL,
        expectedFileBytes: Int64?,
        progressHandler: @escaping (Int64, Int64?) -> Void
    ) {
        self.destinationURL = destinationURL
        self.expectedFileBytes = expectedFileBytes
        self.progressHandler = progressHandler
    }

    static func partialURL(for destinationURL: URL) -> URL {
        destinationURL.appendingPathExtension("download")
    }

    func download(from url: URL) async throws -> Int64 {
        if let existingFinalBytes = fileSize(at: destinationURL) {
            if expectedFileBytes == nil || existingFinalBytes >= (expectedFileBytes ?? 0) {
                progressHandler(existingFinalBytes, expectedFileBytes)
                return existingFinalBytes
            }

            try? FileManager.default.removeItem(at: destinationURL)
        }

        let partialURL = Self.partialURL(for: destinationURL)
        resumeOffset = fileSize(at: partialURL) ?? 0
        if let expectedFileBytes, resumeOffset >= expectedFileBytes {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: partialURL, to: destinationURL)
            progressHandler(resumeOffset, expectedFileBytes)
            return resumeOffset
        }

        expectedTotalBytes = expectedFileBytes
        progressHandler(resumeOffset, expectedFileBytes)

        var request = URLRequest(url: url)
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
            self.session = session
            session.dataTask(with: request).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            terminalError = URLError(.badServerResponse)
            completionHandler(.cancel)
            return
        }

        if httpResponse.statusCode == 416,
           let totalBytes = Self.contentRangeTotal(from: httpResponse.value(forHTTPHeaderField: "Content-Range")),
           resumeOffset >= totalBytes {
            expectedTotalBytes = totalBytes
            partialAlreadyComplete = true
            completionHandler(.cancel)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            terminalError = URLError(.badServerResponse)
            completionHandler(.cancel)
            return
        }

        let partialURL = Self.partialURL(for: destinationURL)
        let canResume = resumeOffset > 0 && httpResponse.statusCode == 206
        if !canResume {
            resumeOffset = 0
            bytesWrittenThisRequest = 0
            try? FileManager.default.removeItem(at: partialURL)
        }

        do {
            if !FileManager.default.fileExists(atPath: partialURL.path) {
                FileManager.default.createFile(atPath: partialURL.path, contents: nil)
            }

            fileHandle = try FileHandle(forWritingTo: partialURL)
            try fileHandle?.seekToEnd()

            if response.expectedContentLength > 0 {
                expectedTotalBytes = resumeOffset + response.expectedContentLength
            } else {
                expectedTotalBytes = expectedFileBytes
            }
            progressHandler(resumeOffset, expectedTotalBytes)
            completionHandler(.allow)
        } catch {
            terminalError = error
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try fileHandle?.write(contentsOf: data)
            bytesWrittenThisRequest += Int64(data.count)
            progressHandler(resumeOffset + bytesWrittenThisRequest, expectedTotalBytes)
        } catch {
            terminalError = error
            dataTask.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        do {
            try fileHandle?.close()
        } catch {
            terminalError = terminalError ?? error
        }
        fileHandle = nil

        self.session?.invalidateAndCancel()
        self.session = nil

        if partialAlreadyComplete {
            do {
                let finalBytes = try finalizePartialDownload(requiredBytes: expectedTotalBytes ?? expectedFileBytes)
                progressHandler(finalBytes, expectedTotalBytes ?? expectedFileBytes)
                continuation?.resume(returning: finalBytes)
            } catch {
                continuation?.resume(throwing: error)
            }
        } else if let terminalError {
            continuation?.resume(throwing: terminalError)
        } else if let error {
            continuation?.resume(throwing: error)
        } else {
            do {
                let finalBytes = try finalizePartialDownload(requiredBytes: expectedTotalBytes ?? expectedFileBytes)
                progressHandler(finalBytes, expectedTotalBytes ?? expectedFileBytes)
                continuation?.resume(returning: finalBytes)
            } catch {
                continuation?.resume(throwing: error)
            }
        }

        continuation = nil
        terminalError = nil
        partialAlreadyComplete = false
        bytesWrittenThisRequest = 0
    }

    private func finalizePartialDownload(requiredBytes: Int64?) throws -> Int64 {
        let partialURL = Self.partialURL(for: destinationURL)
        guard let finalBytes = fileSize(at: partialURL), finalBytes > 0 else {
            throw URLError(.zeroByteResource)
        }

        if let requiredBytes, finalBytes < requiredBytes {
            throw URLError(.networkConnectionLost)
        }

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: partialURL, to: destinationURL)
        return finalBytes
    }

    private func fileSize(at url: URL) -> Int64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int64
        return size.map { $0 > 0 ? $0 : nil } ?? nil
    }

    private static func contentRangeTotal(from value: String?) -> Int64? {
        guard let value, let slashIndex = value.lastIndex(of: "/") else { return nil }
        let suffix = value[value.index(after: slashIndex)...]
        return Int64(suffix)
    }
}
