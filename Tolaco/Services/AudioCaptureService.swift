import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import OSLog

/// Sendable な PCM サンプルラッパー（AVAudioPCMBuffer は本来 non-Sendable だが、
/// このパイプライン上では生成後に変更しない契約で actor 間を渡す）
struct PCMSample: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

final class AudioCaptureService: NSObject, @unchecked Sendable {
    private let logger = Logger(subsystem: "org.nexaspark.tolaco", category: "AudioCapture")
    private var stream: SCStream?
    private var continuation: AsyncStream<PCMSample>.Continuation?

    enum CaptureError: LocalizedError {
        case screenRecordingPermissionDenied
        case noDisplayAvailable
        case shareableContentUnavailable(Error)

        var errorDescription: String? {
            switch self {
            case .screenRecordingPermissionDenied:
                return "画面収録の権限が許可されていません。システム設定 > プライバシーとセキュリティ > 画面収録 で Tolaco を有効化し、アプリを再起動してください。"
            case .noDisplayAvailable:
                return "利用可能なディスプレイが見つかりませんでした。"
            case .shareableContentUnavailable(let error):
                return "画面情報の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func bufferStream() -> AsyncStream<PCMSample> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
        }
    }

    func start() async throws {
        // 画面収録権限のチェック。未許可なら macOS のシステムプロンプトを発火させる。
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            // 許可後はアプリの再起動が必要（macOS の仕様）
            throw CaptureError.screenRecordingPermissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw CaptureError.shareableContentUnavailable(error)
        }

        guard let display = content.displays.first else {
            // 権限はあるはずなのに displays が空 → 念のため permission が剥奪された可能性も提示
            if !CGPreflightScreenCaptureAccess() {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 6

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
        try await newStream.startCapture()
        self.stream = newStream
        logger.info("ScreenCaptureKit audio capture started")
    }

    func stop() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        continuation?.finish()
        continuation = nil
        logger.info("Capture stopped")
    }
}

extension AudioCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
    }
}

extension AudioCaptureService: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio, sampleBuffer.isValid else { return }
        guard let pcm = sampleBuffer.makePCMBuffer() else { return }
        continuation?.yield(PCMSample(buffer: pcm))
    }
}

private extension CMSampleBuffer {
    func makePCMBuffer() -> AVAudioPCMBuffer? {
        guard let formatDesc = formatDescription,
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        else { return nil }

        var asbd = asbdPtr.pointee
        guard let format = AVAudioFormat(streamDescription: &asbd) else { return nil }

        let frameCount = AVAudioFrameCount(numSamples)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }

        buffer.frameLength = frameCount

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self,
            at: 0,
            frameCount: Int32(numSamples),
            into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }
}
