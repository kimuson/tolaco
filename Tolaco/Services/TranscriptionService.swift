import Foundation
import Speech
@preconcurrency import AVFoundation
@preconcurrency import AVFAudio
import OSLog

/// SpeechAnalyzer + SpeechTranscriber を使った英語ストリーミング音声認識。
/// macOS 26 (Tahoe) 以降。完全オンデバイス。
actor TranscriptionService {
    nonisolated private let logger = Logger(subsystem: "org.nexaspark.tolaco", category: "Transcription")

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var resultsTask: Task<Void, Never>?

    struct Hypothesis: Sendable, Identifiable {
        let id = UUID()
        let text: String
        let isFinal: Bool
    }

    enum TranscriptionError: Error {
        case localeNotSupported(Locale)
        case noCompatibleAudioFormat
    }

    func start(locale: Locale = Locale(identifier: "en-US")) async throws -> AsyncStream<Hypothesis> {
        // サポート言語チェック
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            throw TranscriptionError.localeNotSupported(locale)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        // モデルアセット未ダウンロードならダウンロード
        if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            logger.info("Downloading speech assets for \(locale.identifier(.bcp47))")
            try await req.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.noCompatibleAudioFormat
        }
        self.analyzerFormat = analyzerFormat
        logger.info("Analyzer format: \(analyzerFormat.description)")

        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputContinuation

        try await analyzer.start(inputSequence: inputStream)

        let (outStream, outContinuation) = AsyncStream<Hypothesis>.makeStream()

        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    // result.isFinal が無いビルドでは result.resultsFinalizationTime != nil で判定
                    let isFinal = result.isFinal
                    if !text.isEmpty {
                        outContinuation.yield(Hypothesis(text: text, isFinal: isFinal))
                    }
                }
            } catch {
                self.logger.error("Result stream error: \(error.localizedDescription)")
            }
            outContinuation.finish()
        }

        return outStream
    }

    func feed(_ sample: PCMSample) {
        guard let inputContinuation, let analyzerFormat else { return }
        guard let converted = convert(sample.buffer, to: analyzerFormat) else { return }
        inputContinuation.yield(AnalyzerInput(buffer: converted))
    }

    func stop() async {
        inputContinuation?.finish()
        inputContinuation = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil
        analyzerFormat = nil
    }

    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }

        if converter == nil
            || converter?.inputFormat != buffer.format
            || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var provided = false
        let status = converter.convert(to: output, error: &error) { _, statusPtr in
            if provided {
                statusPtr.pointee = .noDataNow
                return nil
            }
            provided = true
            statusPtr.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil {
            logger.error("Audio convert failed: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        return output
    }
}
