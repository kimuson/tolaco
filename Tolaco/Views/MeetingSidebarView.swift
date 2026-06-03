import SwiftUI

enum MeetingSelection: Hashable {
    case live
    case archived(UUID)
}

struct MeetingSidebarView: View {
    @Bindable var meetingStore: MeetingStore
    @Binding var selection: MeetingSelection
    let liveTitle: String?

    @State private var pendingDelete: UUID?

    var body: some View {
        List(selection: $selection) {
            Section("ライブ") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("進行中").font(.headline)
                        if let liveTitle, !liveTitle.isEmpty {
                            Text(liveTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: liveTitle != nil ? "waveform" : "waveform.slash")
                        .foregroundStyle(liveTitle != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                .tag(MeetingSelection.live)
            }

            if !meetingStore.meetings.isEmpty {
                Section("履歴") {
                    ForEach(meetingStore.meetings) { meeting in
                        meetingRow(meeting)
                            .tag(MeetingSelection.archived(meeting.id))
                            .contextMenu {
                                Button("削除", role: .destructive) {
                                    pendingDelete = meeting.id
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .alert("この会議を削除しますか？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let id = pendingDelete {
                    if case .archived(let sel) = selection, sel == id {
                        selection = .live
                    }
                    meetingStore.delete(id: id)
                }
                pendingDelete = nil
            }
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("削除した会議は復元できません。")
        }
    }

    private func meetingRow(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(meeting.title)
                .font(.body)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(meeting.startedAt, style: .date)
                Text(meeting.startedAt, style: .time)
                if meeting.endedAt == nil {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
