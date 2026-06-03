import Foundation
import OSLog
import SwiftUI

/// 会議の永続化と一覧管理。
/// 保存先: ~/Library/Application Support/Tolaco/Meetings/{uuid}.json
/// 一覧はメモリ上にも持ち、変更があれば該当ファイルだけ書き換える。
@MainActor
@Observable
final class MeetingStore {
    private let logger = Logger(subsystem: "org.nexaspark.tolaco", category: "MeetingStore")
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// 新しい順（startedAt 降順）に並んだ会議一覧。
    private(set) var meetings: [Meeting] = []

    init() {
        let fm = FileManager.default
        let resolved: URL
        if let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            resolved = appSupport.appending(path: "Tolaco/Meetings", directoryHint: .isDirectory)
        } else {
            resolved = fm.temporaryDirectory.appending(path: "Tolaco/Meetings", directoryHint: .isDirectory)
        }
        try? fm.createDirectory(at: resolved, withIntermediateDirectories: true)
        self.directory = resolved

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        loadAll()
    }

    // MARK: - Read

    private func loadAll() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            meetings = []
            return
        }
        var loaded: [Meeting] = []
        for url in urls where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let meeting = try decoder.decode(Meeting.self, from: data)
                loaded.append(meeting)
            } catch {
                logger.error("Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        loaded.sort { $0.startedAt > $1.startedAt }
        meetings = loaded
    }

    // MARK: - Write

    /// 既存があれば置き換え、無ければ先頭に挿入。即座にディスクへ書き出す。
    func upsert(_ meeting: Meeting) {
        if let idx = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[idx] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }
        writeToDisk(meeting)
    }

    func rename(id: UUID, to title: String) {
        guard let idx = meetings.firstIndex(where: { $0.id == id }) else { return }
        meetings[idx].title = title
        writeToDisk(meetings[idx])
    }

    func delete(id: UUID) {
        meetings.removeAll { $0.id == id }
        let url = fileURL(for: id)
        try? FileManager.default.removeItem(at: url)
    }

    private func writeToDisk(_ meeting: Meeting) {
        let url = fileURL(for: meeting.id)
        do {
            let data = try encoder.encode(meeting)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save \(meeting.id.uuidString): \(error.localizedDescription)")
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json", directoryHint: .notDirectory)
    }
}
