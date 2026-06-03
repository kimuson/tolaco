import SwiftUI

/// 個別セグメント用のコピーメニュー（右クリック等で使用）。
struct SegmentCopyMenu: View {
    let segment: TranscriptSegment

    var body: some View {
        Button("英文をコピー") {
            TranscriptExporter.copy(segment.sourceText)
        }
        if let ja = segment.translatedText {
            Button("訳文をコピー") {
                TranscriptExporter.copy(ja)
            }
        }
        Button("英＋訳をコピー") {
            TranscriptExporter.copy(TranscriptExporter.bilingual(segment))
        }
    }
}

/// 議事録全体のコピーメニュー（ヘッダ等で使用）。
struct TranscriptCopyMenu: View {
    let segments: [TranscriptSegment]

    var body: some View {
        Menu {
            ForEach(TranscriptExporter.Style.allCases) { style in
                Button(style.label) {
                    let text = TranscriptExporter.format(segments: segments, style: style)
                    TranscriptExporter.copy(text)
                }
            }
        } label: {
            Label("コピー", systemImage: "doc.on.doc")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("議事録全体をクリップボードへ")
    }
}
