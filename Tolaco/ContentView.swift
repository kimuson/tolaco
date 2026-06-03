import SwiftUI

struct ContentView: View {
    @State private var meetingStore = MeetingStore()
    @State private var claude = ClaudeTranslationService()
    @State private var selection: MeetingSelection = .live
    @State private var liveTitle: String?

    var body: some View {
        NavigationSplitView {
            MeetingSidebarView(
                meetingStore: meetingStore,
                selection: $selection,
                liveTitle: liveTitle
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .live:
            LiveTranscriptView(
                meetingStore: meetingStore,
                claude: claude,
                onLiveTitleChange: { liveTitle = $0 }
            )
        case .archived(let id):
            if let meeting = meetingStore.meetings.first(where: { $0.id == id }) {
                MeetingDetailView(
                    meeting: meeting,
                    meetingStore: meetingStore,
                    onDeleted: { selection = .live }
                )
            } else {
                ContentUnavailableView(
                    "会議が見つかりません",
                    systemImage: "questionmark.folder"
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
