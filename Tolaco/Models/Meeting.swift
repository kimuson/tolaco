import Foundation

struct Meeting: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    let startedAt: Date
    var endedAt: Date?
    var segments: [TranscriptSegment]

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        segments: [TranscriptSegment] = []
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.segments = segments
    }

    /// 開始日時から自動生成するデフォルトタイトル（例: "2026-05-29 14:30"）
    static func defaultTitle(at date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
