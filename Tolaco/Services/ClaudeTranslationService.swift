import Foundation
import OSLog

/// 翻訳先として選択できる言語。
/// `rawValue` は `Locale.Language` の識別子であり、Apple Translation / 永続化の双方に使う。
enum TargetLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    /// ピッカー表示用の日本語ラベル。
    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "英語"
        case .chineseSimplified: "中国語（簡体字）"
        case .korean: "韓国語"
        case .spanish: "スペイン語"
        case .french: "フランス語"
        case .german: "ドイツ語"
        }
    }

    /// Claude へのプロンプトに埋め込む英語名。
    var promptName: String {
        switch self {
        case .japanese: "Japanese"
        case .english: "English"
        case .chineseSimplified: "Simplified Chinese"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        }
    }

    var locale: Locale.Language { Locale.Language(identifier: rawValue) }
}

/// Anthropic Messages API を直接叩く高精度翻訳サービス。
/// - 直近の会話履歴を文脈として渡す
/// - システムプロンプト + 用語集は ephemeral cache（5分TTL）で再利用
@MainActor
@Observable
final class ClaudeTranslationService {
    private let logger = Logger(subsystem: "org.nexaspark.tolaco", category: "Claude")

    private static let apiKeyAccount = "anthropic-api-key"
    private static let glossaryKey = "tolaco.glossary"
    private static let enabledKey = "tolaco.claudeEnabled"
    private static let offlineOnlyKey = "tolaco.offlineOnly"
    private static let dialogueModeKey = "tolaco.dialogueMode"
    private static let targetLanguageKey = "tolaco.targetLanguage"
    private static let model = "claude-haiku-4-5-20251001"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    var apiKey: String? {
        didSet {
            if let apiKey, !apiKey.isEmpty {
                try? KeychainStore.set(apiKey, account: Self.apiKeyAccount)
            } else {
                KeychainStore.delete(account: Self.apiKeyAccount)
            }
        }
    }

    var glossary: String {
        didSet { UserDefaults.standard.set(glossary, forKey: Self.glossaryKey) }
    }

    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }

    /// オフライン専用モード。true の間は Claude API へのリクエストを一切発行しない。
    var offlineOnly: Bool {
        didSet { UserDefaults.standard.set(offlineOnly, forKey: Self.offlineOnlyKey) }
    }

    /// 対話モード。true でマイク入力 + デバイス音をミックス。
    var dialogueMode: Bool {
        didSet { UserDefaults.standard.set(dialogueMode, forKey: Self.dialogueModeKey) }
    }

    /// 翻訳先の言語。
    var targetLanguage: TargetLanguage {
        didSet { UserDefaults.standard.set(targetLanguage.rawValue, forKey: Self.targetLanguageKey) }
    }

    var lastError: String?

    var isConfigured: Bool {
        !offlineOnly && (apiKey?.isEmpty == false) && enabled
    }

    init() {
        self.apiKey = KeychainStore.get(account: Self.apiKeyAccount)
        self.glossary = UserDefaults.standard.string(forKey: Self.glossaryKey) ?? ""
        self.enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.offlineOnly = UserDefaults.standard.bool(forKey: Self.offlineOnlyKey)
        self.dialogueMode = UserDefaults.standard.bool(forKey: Self.dialogueModeKey)
        self.targetLanguage = UserDefaults.standard.string(forKey: Self.targetLanguageKey)
            .flatMap(TargetLanguage.init(rawValue:)) ?? .japanese
    }

    /// SSE ストリーミングで高精度翻訳を行う。
    /// - Parameter onDelta: 累積テキストが更新されるたびに main で呼ばれる。途中表示用。
    /// - Returns: 完了後の最終テキスト（trim 済み）。エラー時 nil。
    func translateStreaming(
        text: String,
        history: [TranscriptSegment],
        onDelta: @MainActor @escaping (String) -> Void
    ) async -> String? {
        guard isConfigured, let apiKey, !apiKey.isEmpty else { return nil }

        let systemBlocks = makeSystemBlocks()
        let userContent = makeUserContent(text: text, history: history)

        let body = AnthropicRequest(
            model: Self.model,
            max_tokens: 1024,
            stream: true,
            system: systemBlocks,
            messages: [.init(role: "user", content: userContent)]
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            logger.error("Encode failed: \(error.localizedDescription)")
            return nil
        }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200...299).contains(http.statusCode) else {
                var body = Data()
                for try await byte in bytes { body.append(byte) }
                let bodyText = String(data: body, encoding: .utf8) ?? "<no body>"
                logger.error("HTTP \(http.statusCode): \(bodyText)")
                lastError = "API error \(http.statusCode)"
                return nil
            }

            var accumulated = ""
            let decoder = JSONDecoder()
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                guard !payload.isEmpty, payload != "[DONE]" else { continue }
                guard let data = payload.data(using: .utf8) else { continue }
                guard let event = try? decoder.decode(StreamEvent.self, from: data) else { continue }
                if event.type == "content_block_delta",
                   event.delta?.type == "text_delta",
                   let chunk = event.delta?.text {
                    accumulated += chunk
                    let snapshot = accumulated
                    onDelta(snapshot)
                }
            }
            return accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Prompt construction

    private func makeSystemBlocks() -> [AnthropicRequest.SystemBlock] {
        let language = targetLanguage.promptName
        let instructions = """
        You are a professional real-time translator for online business meetings.
        Translate the user's English text into natural, conversational \(language) suitable for business contexts.

        Strict rules:
        - Output ONLY the \(language) translation. No preamble, no quotes, no source-language text.
        - Preserve the speaker's tone and intent.
        - Use natural \(language) sentence flow rather than a literal word-for-word translation.
        - Use standard \(language) terminology for technical terms.
        - If the input is a partial sentence, translate it as-is without fabricating completion.
        - If the input is a proper noun or contains untranslatable terms, keep them in the original or use the glossary mapping.
        """

        var blocks: [AnthropicRequest.SystemBlock] = [
            .init(text: instructions, cache_control: nil)
        ]

        if !glossary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let glossarySection = """
            GLOSSARY (English → 日本語):
            \(glossary)
            """
            blocks.append(.init(text: glossarySection, cache_control: .ephemeral))
        } else {
            // 用語集がなくても system は cache 対象にしたいので、末尾ブロックに cache_control を付ける
            blocks[0] = .init(text: instructions, cache_control: .ephemeral)
        }
        return blocks
    }

    private func makeUserContent(text: String, history: [TranscriptSegment]) -> String {
        let recent = history.suffix(5)
        if recent.isEmpty {
            return """
            Translate this English text:
            \"\"\"
            \(text)
            \"\"\"
            """
        }

        let contextLines = recent.map { seg -> String in
            let ja = seg.translatedText ?? "(untranslated)"
            return "- EN: \(seg.sourceText)\n  JA: \(ja)"
        }.joined(separator: "\n")

        return """
        Recent conversation context (already translated):
        \(contextLines)

        Translate this new English text in the same style and tone:
        \"\"\"
        \(text)
        \"\"\"
        """
    }
}

// MARK: - Wire types

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    var stream: Bool? = nil
    let system: [SystemBlock]
    let messages: [Message]

    struct SystemBlock: Encodable {
        let type: String
        let text: String
        let cache_control: CacheControl?

        init(text: String, cache_control: CacheControl? = nil) {
            self.type = "text"
            self.text = text
            self.cache_control = cache_control
        }

        struct CacheControl: Encodable {
            let type: String
            static let ephemeral = CacheControl(type: "ephemeral")
        }
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct StreamEvent: Decodable {
    let type: String
    let delta: Delta?

    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
}
