import Foundation

enum TranslationKind: String, Sendable, Hashable, Codable {
    case none
    case tentative  // Apple Translation 結果
    case polished   // Claude による上書き本訳
}

struct TranscriptSegment: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var sourceText: String
    var translatedText: String?
    var translationKind: TranslationKind
    var isFinal: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String? = nil,
        translationKind: TranslationKind = .none,
        isFinal: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.translationKind = translationKind
        self.isFinal = isFinal
        self.createdAt = createdAt
    }
}
