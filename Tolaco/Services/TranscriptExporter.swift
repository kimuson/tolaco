import Foundation
import AppKit

/// 議事録セグメントを各種フォーマットの文字列に整形し、クリップボードへ流す。
enum TranscriptExporter {
    enum Style: String, CaseIterable, Identifiable {
        case translatedOnly
        case bilingual
        case markdown

        var id: String { rawValue }

        var label: String {
            switch self {
            case .translatedOnly: return "訳文のみ"
            case .bilingual: return "英文＋訳文"
            case .markdown: return "Markdown"
            }
        }
    }

    static func format(segments: [TranscriptSegment], style: Style) -> String {
        switch style {
        case .translatedOnly:
            return segments
                .map { $0.translatedText ?? $0.sourceText }
                .joined(separator: "\n")

        case .bilingual:
            return segments.map { seg in
                if let ja = seg.translatedText {
                    return "EN: \(seg.sourceText)\nJA: \(ja)"
                } else {
                    return "EN: \(seg.sourceText)"
                }
            }.joined(separator: "\n\n")

        case .markdown:
            return segments.map { seg in
                if let ja = seg.translatedText {
                    return "- **EN**: \(seg.sourceText)\n  - **JA**: \(ja)"
                } else {
                    return "- **EN**: \(seg.sourceText)"
                }
            }.joined(separator: "\n")
        }
    }

    static func bilingual(_ segment: TranscriptSegment) -> String {
        if let ja = segment.translatedText {
            return "EN: \(segment.sourceText)\nJA: \(ja)"
        }
        return "EN: \(segment.sourceText)"
    }

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
