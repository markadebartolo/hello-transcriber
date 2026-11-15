import AVFoundation
import Foundation

private final class TestSession: BuddyStreamingTranscriptionSession, @unchecked Sendable {
    let finalTranscriptFallbackDelaySeconds: TimeInterval = 0.03
    private let lock = NSLock()
    private var cancellations = 0
    var cancelled: Bool { lock.withLock { cancellations > 0 } }
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    func requestFinalTranscript() {}
    func cancel() { lock.withLock { cancellations += 1 } }
}

@MainActor
private final class TestCapture: BuddyAudioCapture {
    var running = false
    var failStart = false
    func start(consume: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        if failStart { throw TestError.failed }
        running = true
    }
    func stop() { running = false }
}
private enum TestError: Error { case failed }

@MainActor
private final class TestProvider: BuddyTranscriptionProvider {
    let displayName = "test"
    let requiresSpeechRecognitionPermission = false
    let isConfigured = true
    let unavailableExplanation: String? = nil
    struct Call {
        let session: TestSession
        let partial: @Sendable (String) -> Void
        let final: @Sendable (String) -> Void
        let error: @Sendable (Error) -> Void
    }
    var calls: [Call] = []
    var pauseNextStart = false
    var continuation: CheckedContinuation<Void, Never>?
    func startStreamingSession(keyterms: [String], onTranscriptUpdate: @escaping @Sendable (String) -> Void,
        onFinalTranscriptReady: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void) async throws -> any BuddyStreamingTranscriptionSession {
        let session = TestSession()
        calls.append(Call(session: session, partial: onTranscriptUpdate, final: onFinalTranscriptReady, error: onError))
        if pauseNextStart {
            pauseNextStart = false
            await withCheckedContinuation { continuation = $0 }
        }
        return session
    }
}

@main
struct HelloLifecycleTests {
    @MainActor static func main() async {
        // Invoke the exact production AVAudioEngine tap handler off-main.
        // The old inline SDK block inherited MainActor and trapped on buffer 1.
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            let handler = BuddyMicrophoneCapture.makeTapHandler { buffer in
                precondition(!Thread.isMainThread)
                precondition(buffer.frameLength == 32)
                precondition(buffer.floatChannelData![0][0] == 0.25)
                done.resume()
            }
            DispatchQueue.global().async {
                let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32)!
                buffer.frameLength = 32
                buffer.floatChannelData![0][0] = 0.25
                handler(buffer, AVAudioTime(sampleTime: 0, atRate: 48_000))
            }
        }
        MainActor.assertIsolated()
        // Exercise the actual permission bridge from MainActor with TCC-style
        // background completion. An actor-inheriting callback traps in Swift 6.
        for expected in [true, false] {
            let result: Bool = await BuddyPermissionBridge.request { completion in
                DispatchQueue.global().async { completion(expected) }
            }
            precondition(result == expected)
            MainActor.assertIsolated()
        }
        let synchronous: Bool = await BuddyPermissionBridge.request { completion in completion(true) }
        precondition(synchronous)
        let provider = TestProvider()
        let capture = TestCapture()
        let manager = BuddyDictationManager(transcriptionProvider: provider, audioCapture: capture, permissionCheck: { true })
        var delivered: [String] = []
        var liveUpdates: [String] = []
        func start() async {
            await manager.startPushToTalkFromKeyboardShortcut(currentDraftText: "", updateDraftText: { liveUpdates.append($0) }, submitDraftText: { delivered.append($0) })
        }
        func drain() async { try? await Task.sleep(for: .milliseconds(80)) }
        func waitUntil(_ description: String, _ condition: () -> Bool) async {
            let deadline = Date().addingTimeInterval(5)
            while !condition(), Date() < deadline {
                try? await Task.sleep(for: .milliseconds(10))
            }
            precondition(condition(), "Timed out waiting for " + description)
        }
        func requireCalls(_ count: Int) {
            precondition(provider.calls.count == count, "Expected \(count) starts; got \(provider.calls.count). Busy=\(manager.isDictationInProgress), error=\(manager.lastErrorMessage ?? "none")")
        }

        // Quick release while provider startup is suspended, then a new session.
        provider.pauseNextStart = true
        let oldStart = Task { await start() }
        while provider.continuation == nil { await Task.yield() }
        manager.stopPushToTalkFromKeyboardShortcut()
        await start()
        provider.continuation?.resume(); provider.continuation = nil
        await oldStart.value
        precondition(provider.calls[0].session.cancelled)
        precondition(capture.running && manager.isActivelyRecordingAudio)
        requireCalls(2)
        provider.calls[0].partial("OLD PARTIAL")
        provider.calls[0].final("OLD FINAL")
        provider.calls[0].error(TestError.failed)
        await drain()
        precondition(delivered.isEmpty && capture.running, "Stale callback changed new session")
        precondition(liveUpdates.isEmpty, "Stale partial appeared in live captions")

        // Recognition revisions replace the live words, rather than appending
        // duplicate partial sentences. They must arrive before key release.
        provider.calls[1].partial("Hello May")
        await waitUntil("first live partial", { liveUpdates.count == 1 })
        provider.calls[1].partial("Hello Maya")
        await waitUntil("revised live partial", { liveUpdates.count == 2 })
        precondition(liveUpdates == ["Hello May", "Hello Maya"] && capture.running)

        // Current final exactly once, with duplicate/out-of-order callbacks ignored.
        manager.stopPushToTalkFromKeyboardShortcut()
        provider.calls[1].final("current")
        provider.calls[1].final("duplicate")
        await waitUntil("first final", { !manager.isDictationInProgress })
        precondition(delivered == ["current"] && !capture.running && !manager.isDictationInProgress)

        // Cancel after stop but before fallback; old fallback cannot finalize new work.
        await start()
        requireCalls(3)
        provider.calls[2].partial("cancel me")
        await drain()
        manager.stopPushToTalkFromKeyboardShortcut()
        manager.cancelCurrentDictation(preserveDraftText: false)
        await start()
        await drain()
        precondition(capture.running && delivered == ["current"])
        manager.cancelCurrentDictation(preserveDraftText: false)
        requireCalls(4)
        provider.calls[3].final("after cancel")
        await waitUntil("first final", { !manager.isDictationInProgress })
        precondition(delivered == ["current"] && !capture.running)

        // Empty audio does not submit. Partial text survives a final-result timeout.
        await start(); requireCalls(5); manager.stopPushToTalkFromKeyboardShortcut()
        await waitUntil("empty fallback", { !manager.isDictationInProgress })
        precondition(delivered == ["current"])
        await start(); requireCalls(6); provider.calls[5].partial("fallback")
        await drain(); manager.stopPushToTalkFromKeyboardShortcut()
        await waitUntil("partial fallback", { !manager.isDictationInProgress })
        precondition(delivered == ["current", "fallback"])

        // Engine failure must cancel the provider and leave no hot microphone.
        capture.failStart = true
        await start()
        precondition(provider.calls.last!.session.cancelled && !manager.isDictationInProgress && !capture.running)
        capture.failStart = false

        // A task already cancelled before entry must not start recording.
        let cancelled = Task { await Task.yield(); await start() }
        cancelled.cancel(); await cancelled.value
        precondition(!capture.running && provider.calls.count == 7)

        // A permission completion from a cancelled start cannot reset a later one.
        var permissionContinuation: CheckedContinuation<Bool, Never>?
        var firstPermission = true
        let permissionManager = BuddyDictationManager(transcriptionProvider: provider, audioCapture: capture, permissionCheck: {
            if firstPermission {
                firstPermission = false
                return await withCheckedContinuation { permissionContinuation = $0 }
            }
            return true
        })
        let permissionStart = Task {
            await permissionManager.startPushToTalkFromKeyboardShortcut(currentDraftText: "", updateDraftText: { _ in }, submitDraftText: { _ in })
        }
        while permissionContinuation == nil { await Task.yield() }
        permissionManager.cancelCurrentDictation(preserveDraftText: false)
        await permissionManager.startPushToTalkFromKeyboardShortcut(currentDraftText: "", updateDraftText: { _ in }, submitDraftText: { _ in })
        permissionContinuation?.resume(returning: false)
        await permissionStart.value
        precondition(capture.running && permissionManager.isActivelyRecordingAudio)
        permissionManager.cancelCurrentDictation(preserveDraftText: false)
        print("Hello lifecycle: 12 regression scenarios passed (injected provider/audio and real tap handler; no microphone access)")
    }
}
