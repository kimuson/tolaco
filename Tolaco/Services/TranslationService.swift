import Foundation
@preconcurrency import Translation
import SwiftUI
import OSLog

/// Apple Translation framework のラッパー。
/// `TranslationSession` は SwiftUI の `.translationTask` 経由でしか取れないため、
/// View 側で session を流し込んでもらう設計にしている。
@MainActor
@Observable
final class TranslationService {
    private let logger = Logger(subsystem: "org.nexaspark.tolaco", category: "Translation")

    var session: TranslationSession?
    private var translationQueue: [String] = []
    private var isTranslating = false

    func translate(_ text: String) async -> String? {
        // 短いテキストはスキップ（ノイズ減少）
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty,
              text.count >= 3 else {
            return nil
        }

        guard let session else {
            logger.warning("TranslationSession not yet available")
            return nil
        }

        // 翻訳キューに追加
        translationQueue.append(text)

        // 既に翻訳中なら待つ
        if isTranslating {
            // キューの最後のテキストだけを処理
            while translationQueue.count > 1 {
                translationQueue.removeFirst()
            }
            return nil
        }

        isTranslating = true
        defer { isTranslating = false }

        do {
            let response = try await session.translate(text)
            translationQueue.removeAll()
            return response.targetText
        } catch {
            logger.error("Translation failed: \(error.localizedDescription)")
            translationQueue.removeAll()
            return nil
        }
    }
}
