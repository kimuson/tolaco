import SwiftUI

/// 保存済み会議の読み取り専用ビュー。タイトル編集と削除のみ可能。
struct MeetingDetailView: View {
    let meeting: Meeting
    @Bindable var meetingStore: MeetingStore
    var onDeleted: () -> Void

    @State private var titleDraft: String = ""
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcriptList
        }
        .onAppear {
            titleDraft = meeting.title
        }
        .onChange(of: meeting.id) { _, _ in
            titleDraft = meeting.title
        }
        .alert("この会議を削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                meetingStore.delete(id: meeting.id)
                onDeleted()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した会議は復元できません。")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("会議タイトル", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
                .font(.title3.weight(.semibold))
                .onSubmit { commitRename() }
                .frame(maxWidth: 360)

            if titleDraft != meeting.title {
                Button("保存") { commitRename() }
            }

            Spacer()

            TranscriptCopyMenu(segments: meeting.segments)
                .disabled(meeting.segments.isEmpty)

            VStack(alignment: .trailing, spacing: 2) {
                Text(meeting.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.callout)
                if let ended = meeting.endedAt {
                    Text("〜 \(ended, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未完了").font(.caption).foregroundStyle(.orange)
                }
            }

            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .padding(12)
    }

    private var transcriptList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if meeting.segments.isEmpty {
                    ContentUnavailableView(
                        "セグメントがありません",
                        systemImage: "text.alignleft"
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(meeting.segments) { segment in
                        segmentRow(segment)
                    }
                }
            }
            .padding(12)
        }
    }

    private func segmentRow(_ segment: TranscriptSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(segment.sourceText)
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let translated = segment.translatedText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(translated)
                        .font(.system(.title3, design: .default).weight(.medium))
                        .foregroundStyle(
                            segment.translationKind == .polished ? .primary : .secondary
                        )
                        .textSelection(.enabled)
                    if segment.translationKind == .polished {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu { SegmentCopyMenu(segment: segment) }
    }

    private func commitRename() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != meeting.title else {
            titleDraft = meeting.title
            return
        }
        meetingStore.rename(id: meeting.id, to: trimmed)
    }
}
