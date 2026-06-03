import Foundation
import SwiftUI

@MainActor
@Observable
final class TranscriptStore {
    /// 確定したセグメント（古いほど先頭）
    private(set) var finalSegments: [TranscriptSegment] = []
    /// 現在進行中の暫定セグメント
    var volatileSegment: TranscriptSegment?

    /// 進行中の会議のメタ情報。`startMeeting(title:)` でセットされる。
    private(set) var currentMeetingID: UUID?
    var currentMeetingTitle: String = ""
    private(set) var currentMeetingStartedAt: Date?
    private(set) var currentMeetingEndedAt: Date?

    /// 単調増加するリビジョン。永続化レイヤがこの値の変化を観測して debounce 保存する。
    private(set) var revision: Int = 0

    /// 新しい会議の開始。既存の進行中状態は破棄される。
    func startMeeting(title: String, at date: Date = .now) {
        currentMeetingID = UUID()
        currentMeetingTitle = title
        currentMeetingStartedAt = date
        currentMeetingEndedAt = nil
        finalSegments.removeAll()
        volatileSegment = nil
        bumpRevision()
    }

    /// 現在の会議を終了状態にする。
    func endMeeting(at date: Date = .now) {
        guard currentMeetingID != nil else { return }
        currentMeetingEndedAt = date
        volatileSegment = nil
        bumpRevision()
    }

    /// 現在の進行中会議のスナップショット。会議未開始なら nil。
    func snapshotMeeting() -> Meeting? {
        guard let id = currentMeetingID, let started = currentMeetingStartedAt else { return nil }
        return Meeting(
            id: id,
            title: currentMeetingTitle,
            startedAt: started,
            endedAt: currentMeetingEndedAt,
            segments: finalSegments
        )
    }

    /// 認識器から来た仮説を反映
    func ingest(text: String, isFinal: Bool) -> UUID? {
        if isFinal {
            let segment = TranscriptSegment(sourceText: text, isFinal: true)
            finalSegments.append(segment)
            volatileSegment = nil
            bumpRevision()
            return segment.id
        } else {
            if var existing = volatileSegment {
                existing.sourceText = text
                volatileSegment = existing
            } else {
                volatileSegment = TranscriptSegment(sourceText: text, isFinal: false)
            }
            return nil
        }
    }

    func setTranslation(_ translation: String, kind: TranslationKind, for id: UUID) {
        guard let idx = finalSegments.firstIndex(where: { $0.id == id }) else { return }
        // polished が既にあるなら tentative で上書きしない
        if finalSegments[idx].translationKind == .polished && kind == .tentative { return }
        finalSegments[idx].translatedText = translation
        finalSegments[idx].translationKind = kind
        bumpRevision()
    }

    func clear() {
        finalSegments.removeAll()
        volatileSegment = nil
        currentMeetingID = nil
        currentMeetingTitle = ""
        currentMeetingStartedAt = nil
        currentMeetingEndedAt = nil
        bumpRevision()
    }

    private func bumpRevision() {
        revision &+= 1
    }
}
