import AVFoundation
import Foundation

private final class SpeechProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var finals: [String] = []
    private var errors = 0
    private var notices: [String] = []

    func final(_ value: String) { lock.withLock { finals.append(value) } }
    func fail() { lock.withLock { errors += 1 } }
    var results: [String] { lock.withLock { finals } }
    var errorCount: Int { lock.withLock { errors } }
    func fallback(_ reason: String) { lock.withLock { notices.append(reason) } }
    var fallbackNotices: [String] { lock.withLock { notices } }
}

private final class TestAppleSession: BuddyStreamingTranscriptionSession {
    let finalTranscriptFallbackDelaySeconds: TimeInterval = 1
    func appendAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {}
    func requestFinalTranscript() {}
    func cancel() {}
}

@main
struct HelloOpenAITranscriptionTests {
    @MainActor static func main() async throws {
        let pcm = Data([0x34, 0x12, 0x00, 0x00])
        let wav = HelloOpenAITranscriptionClient.wav(pcm: pcm, sampleRate: 16_000)
        precondition(wav.count == 48)
        precondition(String(decoding: wav[0..<4], as: UTF8.self) == "RIFF")
        precondition(wav[4..<8].elementsEqual([40, 0, 0, 0]))
        precondition(wav[24..<28].elementsEqual([0x80, 0x3e, 0, 0]))
        precondition(wav.suffix(4).elementsEqual(pcm))
        let request = HelloOpenAITranscriptionClient.request(wav: wav, key: "fixture-key", boundary: "hello-fixture")
        precondition(request.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        precondition(request.httpMethod == "POST")
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-key")
        let body = request.httpBody!
        let envelope = String(decoding: body, as: UTF8.self)
        precondition(envelope.contains("gpt-transcribe") && envelope.contains("filename=\"dictation.wav\""))
        precondition(body.range(of: wav) != nil && !envelope.contains("name=\"prompt\""))
        let text = try HelloOpenAITranscriptionClient.transcript(data: Data(#"{"text":" Hello there. "}"#.utf8), status: 200)
        precondition(text == "Hello there.")
        for status in [401, 403, 429, 500] {
            do {
                _ = try HelloOpenAITranscriptionClient.transcript(data: Data(#"{"text":"never insert"}"#.utf8), status: status)
                preconditionFailure("A failed HTTP response must not become a transcript")
            } catch is HelloOpenAITranscriptionError {}
        }
        do {
            _ = try HelloOpenAITranscriptionClient.transcript(data: Data("invalid".utf8), status: 200)
            preconditionFailure("Malformed responses must not become transcripts")
        } catch is HelloOpenAITranscriptionError {}
        let probe = SpeechProbe()
        let provider = HelloOpenAITranscriptionProvider(readKey: { "fixture-key" })
        precondition(!provider.requiresSpeechRecognitionPermission)
        let silent = try await provider.startStreamingSession(keyterms: [], onTranscriptUpdate: { _ in },
            onFinalTranscriptReady: { probe.final($0) }, onError: { _ in probe.fail() })
        silent.requestFinalTranscript()
        silent.requestFinalTranscript()
        let cancelled = try await provider.startStreamingSession(keyterms: [], onTranscriptUpdate: { _ in },
            onFinalTranscriptReady: { probe.final($0) }, onError: { _ in probe.fail() })
        cancelled.cancel()
        cancelled.requestFinalTranscript()
        precondition(probe.results == [""] && probe.errorCount == 0)
        let missingKey = HelloOpenAITranscriptionProvider(readKey: { nil })
        do {
            _ = try await missingKey.startStreamingSession(keyterms: [], onTranscriptUpdate: { _ in },
                onFinalTranscriptReady: { probe.final($0) }, onError: { _ in probe.fail() })
            preconditionFailure("A missing key must not start recording")
        } catch is HelloOpenAITranscriptionError {}
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let signal = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2000)!
        signal.frameLength = 2000
        signal.floatChannelData!.pointee.update(repeating: 0.1, count: 2000)
        let appleResult = HelloLocalSpeechResult()
        appleResult.finish("Apple completed words.")
        let successProbe = SpeechProbe()
        let cloudSuccess = HelloOpenAIAudioSession(apiKey: "fixture-key", appleSession: TestAppleSession(),
            appleResult: appleResult, onFallback: { successProbe.fallback($0) },
            onFinal: { successProbe.final($0) }, onError: { _ in successProbe.fail() },
            transcribe: { wav, _ in
                precondition(wav.count == 4044)
                return "OpenAI final words."
            })
        cloudSuccess.appendAudioBuffer(signal)
        cloudSuccess.requestFinalTranscript()
        for _ in 0..<100 where successProbe.results.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        precondition(successProbe.results == ["OpenAI final words."] && successProbe.fallbackNotices.isEmpty)

        let failureProbe = SpeechProbe()
        let cloudFailure = HelloOpenAIAudioSession(apiKey: "fixture-key", appleSession: TestAppleSession(),
            appleResult: appleResult, onFallback: { failureProbe.fallback($0) },
            onFinal: { failureProbe.final($0) }, onError: { _ in failureProbe.fail() },
            transcribe: { _, _ in throw HelloOpenAITranscriptionError(message: "Check your OpenAI key.") })
        cloudFailure.appendAudioBuffer(signal)
        cloudFailure.requestFinalTranscript()
        for _ in 0..<100 where failureProbe.results.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        precondition(failureProbe.results == ["Apple completed words."] && failureProbe.fallbackNotices == ["Check your OpenAI key."])

        let noFallbackProbe = SpeechProbe()
        let noApple = HelloLocalSpeechResult()
        noApple.finish(nil)
        let noFallback = HelloOpenAIAudioSession(apiKey: "fixture-key", appleSession: TestAppleSession(),
            appleResult: noApple, onFallback: { noFallbackProbe.fallback($0) },
            onFinal: { noFallbackProbe.final($0) }, onError: { _ in noFallbackProbe.fail() },
            transcribe: { _, _ in throw HelloOpenAITranscriptionError(message: "Network error.") })
        noFallback.appendAudioBuffer(signal)
        noFallback.requestFinalTranscript()
        for _ in 0..<100 where noFallbackProbe.errorCount == 0 { try await Task.sleep(for: .milliseconds(10)) }
        precondition(noFallbackProbe.errorCount == 1 && noFallbackProbe.results.isEmpty)
        print("OpenAI final text takes priority and Apple fallback requires a completed result and reports the failure")
        print("Hello OpenAI speech: WAV, request privacy, response errors, missing key, silence and cancellation passed (fixtures only)")
    }
}
