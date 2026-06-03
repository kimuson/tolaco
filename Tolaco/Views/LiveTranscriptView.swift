import SwiftUI
import Translation
import AppKit
@preconcurrency import AVFAudio

/// ライブ文字起こし + 翻訳のメイン画面。
/// 録音開始時に MeetingStore に新規 Meeting を作成し、進行中は debounce 保存、停止時に最終保存する。
struct LiveTranscriptView: View {
    @Bindable var meetingStore: MeetingStore
    @Bindable var claude: ClaudeTranslationService
    var onLiveTitleChange: (String?) -> Void = { _ in }

    @State private var store = TranscriptStore()
    @State private var translation = TranslationService()
    @State private var captureService = AudioCaptureService()
    @State private var transcriptionService = TranscriptionService()

    @State private var isRunning = false
    @State private var status: String = "待機中"
    @State private var errorMessage: String?
    @State private var errorIsPermission = false
    @State private var audioTask: Task<Void, Never>?
    @State private var hypothesisTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    @State private var showingSettings = false

    private var translationConfig: TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: claude.targetLanguage.locale
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcriptList
            if let live = store.volatileSegment {
                Divider()
                liveRow(live)
            }
        }
        .translationTask(translationConfig) { session in
            translation.session = session
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(service: claude)
        }
        .onChange(of: store.revision) { _, _ in
            scheduleSave()
        }
        .onChange(of: store.currentMeetingTitle) { _, _ in
            notifyLiveTitle()
        }
        .onChange(of: store.currentMeetingID) { _, _ in
            notifyLiveTitle()
        }
        .onDisappear {
            saveTask?.cancel()
            persistSnapshot()
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            if errorIsPermission {
                Button("システム設定を開く") {
                    openScreenRecordingSettings()
                    errorMessage = nil
                }
                Button("キャンセル", role: .cancel) { errorMessage = nil }
            } else {
                Button("OK") { errorMessage = nil }
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Task { await toggle() }
            } label: {
                Label(isRunning ? "停止" : "開始", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.return, modifiers: [.command])

            if store.currentMeetingID != nil {
                TextField("会議タイトル", text: $store.currentMeetingTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit { scheduleSave(immediate: true) }
            }

            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)

            if claude.offlineOnly {
                Label("オフライン専用", systemImage: "airplane")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .help("オフライン専用モード（外部 API なし）")
            } else if claude.isConfigured {
                Label("Claude 本訳 ON", systemImage: "sparkles")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tint)
                    .help("Claude Haiku で本訳が有効")
            }

            Spacer()

            TranscriptCopyMenu(segments: store.finalSegments)
                .disabled(store.finalSegments.isEmpty)

            Button {
                showingSettings = true
            } label: {
                Label("設定", systemImage: "gearshape")
            }

            Button {
                store.clear()
            } label: {
                Label("クリア", systemImage: "trash")
            }
            .disabled(isRunning || (store.finalSegments.isEmpty && store.volatileSegment == nil && store.currentMeetingID == nil))
            .help("表示中のライブ転写を空にします（保存済みの会議は影響を受けません）")
        }
        .padding(12)
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.finalSegments) { segment in
                        segmentRow(segment)
                            .id(segment.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .onChange(of: store.finalSegments.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func segmentRow(_ segment: TranscriptSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(segment.sourceText)
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let translated = segment.translatedText {
                    Text(translated)
                        .font(.system(.title3, design: .default).weight(.medium))
                        .foregroundStyle(
                            segment.translationKind == .polished ? .primary : .secondary
                        )
                        .textSelection(.enabled)
                } else {
                    Text("翻訳中…")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                switch segment.translationKind {
                case .polished:
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .help("Claude による本訳")
                case .tentative:
                    Image(systemName: "hourglass")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("仮訳（本訳待ち）")
                case .none:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu { SegmentCopyMenu(segment: segment) }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: segment.translationKind)
    }

    private func liveRow(_ segment: TranscriptSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("リアルタイム", systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(.tint)
            Text(segment.sourceText)
                .font(.body)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
    }

    // MARK: - Pipeline

    private func toggle() async {
        if isRunning {
            await stop()
        } else {
            await start()
        }
    }

    private func start() async {
        do {
            status = "音声認識モデルを準備中…"
            let hypothesisStream = try await transcriptionService.start(
                locale: Locale(identifier: "en-US")
            )

            status = "システム音声を取得中…"
            try await captureService.start()
            let deviceAudioStream = captureService.bufferStream()

            store.startMeeting(title: Meeting.defaultTitle())
            persistSnapshot()

            isRunning = true
            status = "実行中"

            audioTask = Task { @MainActor in
                for await buffer in deviceAudioStream {
                    await transcriptionService.feed(buffer)
                }
            }

            hypothesisTask = Task { @MainActor in
                for await hypothesis in hypothesisStream {
                    if let finalizedId = store.ingest(
                        text: hypothesis.text,
                        isFinal: hypothesis.isFinal
                    ) {
                        self.translateSegment(id: finalizedId, sourceText: hypothesis.text)
                    }
                }
            }

        } catch {
            errorMessage = error.localizedDescription
            if case AudioCaptureService.CaptureError.screenRecordingPermissionDenied = error {
                errorIsPermission = true
                status = "画面収録権限が必要"
            } else {
                errorIsPermission = false
                status = "エラー"
            }
            await stop()
        }
    }

    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// 仮訳（Apple）→ 本訳（Claude）の二段階翻訳をキックする。
    private func translateSegment(id: UUID, sourceText: String) {
        Task { @MainActor in
            if let translated = await translation.translate(sourceText) {
                store.setTranslation(translated, kind: .tentative, for: id)
            }
        }

        guard claude.isConfigured else { return }
        let history = store.finalSegments
        Task { @MainActor in
            _ = await claude.translateStreaming(
                text: sourceText,
                history: history
            ) { partial in
                store.setTranslation(partial, kind: .polished, for: id)
            }
        }
    }

    private func stop() async {
        isRunning = false
        status = "停止中…"
        audioTask?.cancel()
        hypothesisTask?.cancel()
        audioTask = nil
        hypothesisTask = nil
        await captureService.stop()
        await transcriptionService.stop()
        store.endMeeting()
        saveTask?.cancel()
        persistSnapshot()
        status = "待機中"
    }

    // MARK: - Persistence

    /// store.revision の変化に応じて 2秒後に書き出す。連打されたら遅延がリセットされる。
    private func scheduleSave(immediate: Bool = false) {
        saveTask?.cancel()
        if immediate {
            persistSnapshot()
            return
        }
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            persistSnapshot()
        }
    }

    private func persistSnapshot() {
        guard let snapshot = store.snapshotMeeting() else { return }
        meetingStore.upsert(snapshot)
    }

    private func notifyLiveTitle() {
        if store.currentMeetingID != nil {
            onLiveTitleChange(store.currentMeetingTitle)
        } else {
            onLiveTitleChange(nil)
        }
    }
}
