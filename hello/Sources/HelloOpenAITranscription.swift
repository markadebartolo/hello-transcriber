import AVFoundation
import Foundation

struct HelloOpenAITranscriptionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct HelloOpenAITranscriptionProvider: BuddyTranscriptionProvider {
    let readKey: () -> String?
    let displayName = "OpenAI"
    let requiresSpeechRecognitionPermission = false
    let isConfigured = true
    let unavailableExplanation: String? = nil

    func startStreamingSession(
        keyterms: [String],
        onTranscriptUpdate: @escaping @Sendable (String) -> Void,
        onFinalTranscriptReady: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async throws -> any BuddyStreamingTranscriptionSession {
        guard let key = readKey() else {
            throw HelloOpenAITranscriptionError(message: "Add your OpenAI API key in Dictation settings.")
        }
        return HelloOpenAIAudioSession(apiKey: key, onFinal: onFinalTranscriptReady, onError: onError)
    }
}

/// Buffers the recording in memory and sends it when the user releases the keys.
private final class HelloOpenAIAudioSession: BuddyStreamingTranscriptionSession, @unchecked Sendable {
    let finalTranscriptFallbackDelaySeconds: TimeInterval = 35
    private let lock = NSLock()
    private let apiKey: String
    private let onFinal: @Sendable (String) -> Void
    private let onError: @Sendable (Error) -> Void
    private var sampleRate: UInt32?
    private var pcm = Data()
    private var hasSignal = false
    private var invalidFormat = false
    private var stopped = false
    private var cancelled = false
    private var request: Task<Void, Never>?

    init(apiKey: String, onFinal: @escaping @Sendable (String) -> Void,
         onError: @escaping @Sendable (Error) -> Void) {
        self.apiKey = apiKey
        self.onFinal = onFinal
        self.onError = onError
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard !stopped, !cancelled, !invalidFormat else { return }
            let rate = audioBuffer.format.sampleRate
            guard rate.isFinite, rate >= 8_000, rate <= 192_000,
                  let channel = audioBuffer.floatChannelData?.pointee else {
                invalidFormat = true
                return
            }
            let roundedRate = UInt32(rate.rounded())
            guard sampleRate == nil || sampleRate == roundedRate else {
                invalidFormat = true
                return
            }
            sampleRate = roundedRate
            let remaining = Int(roundedRate) * 60 - pcm.count / 2
            let count = min(remaining, Int(audioBuffer.frameLength))
            guard count > 0 else { return }
            let stride = audioBuffer.stride
            var samples = [Int16]()
            samples.reserveCapacity(count)
            for index in 0..<count {
                let value = channel[index * stride]
                let sample = value.isFinite ? max(-1, min(1, value)) : 0
                if abs(sample) > 0.002 { hasSignal = true }
                samples.append(Int16(sample * Float(Int16.max)).littleEndian)
            }
            samples.withUnsafeBytes { pcm.append(contentsOf: $0) }
        }
    }

    func requestFinalTranscript() {
        lock.withLock {
            guard !stopped, !cancelled else { return }
            stopped = true
            let audio = pcm
            pcm = Data()
            if invalidFormat {
                onError(HelloOpenAITranscriptionError(message: "The microphone format changed or isn’t supported. Try recording again."))
                return
            }
            guard let sampleRate, hasSignal, audio.count >= Int(sampleRate) / 5 else {
                onFinal("")
                return
            }
            request = Task.detached { [weak self, apiKey] in
                do {
                    try Task.checkCancellation()
                    let wav = HelloOpenAITranscriptionClient.wav(pcm: audio, sampleRate: sampleRate)
                    let text = try await HelloOpenAITranscriptionClient.transcribe(wav: wav, key: apiKey)
                    try Task.checkCancellation()
                    self?.finish(.success(text))
                } catch is CancellationError {
                    // The manager has already invalidated this recording.
                } catch {
                    self?.finish(.failure(error))
                }
            }
        }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
            pcm = Data()
            request?.cancel()
            request = nil
        }
    }

    private func finish(_ result: Result<String, Error>) {
        lock.withLock {
            guard !cancelled else { return }
            request = nil
            switch result {
            case .success(let text): onFinal(text)
            case .failure(let error): onError(error)
            }
        }
    }
}

enum HelloOpenAITranscriptionClient {
    static let model = "gpt-transcribe"
    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    static func wav(pcm: Data, sampleRate: UInt32) -> Data {
        var wav = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ number: T) {
            var littleEndian = number.littleEndian
            withUnsafeBytes(of: &littleEndian) { wav.append(contentsOf: $0) }
        }
        append(UInt32(36 + pcm.count))
        wav.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(UInt16(1)) // Mono
        append(sampleRate)
        append(sampleRate * 2)
        append(UInt16(2))
        append(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        append(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }

    static func request(wav: Data, key: String, boundary: String = UUID().uuidString) -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n\(model)\r\n".utf8)
        body.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8)
        body.append(wav)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        request.httpBody = body
        return request
    }

    static func transcribe(wav: Data, key: String) async throws -> String {
        try Task.checkCancellation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration,
                                 delegate: HelloTranscriptionNoRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request(wav: wav, key: key))
        } catch {
            try Task.checkCancellation()
            throw HelloOpenAITranscriptionError(message: "Couldn’t reach OpenAI. Check your connection and try again.")
        }
        return try transcript(data: data, status: (response as? HTTPURLResponse)?.statusCode)
    }

    static func transcript(data: Data, status: Int?) throws -> String {
        switch status {
        case 401, 403:
            throw HelloOpenAITranscriptionError(message: "OpenAI rejected this key. Check its transcription access in Dictation settings.")
        case 429:
            throw HelloOpenAITranscriptionError(message: "OpenAI is rate limited or the account has reached its usage limit.")
        case 200:
            struct Response: Decodable { let text: String }
            guard data.count <= 256_000,
                  let response = try? JSONDecoder().decode(Response.self, from: data),
                  response.text.utf16.count <= 32_000 else {
                throw HelloOpenAITranscriptionError(message: "OpenAI returned an unreadable transcription. Try again.")
            }
            return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            throw HelloOpenAITranscriptionError(message: "OpenAI couldn’t transcribe the recording. Try again.")
        }
    }
}

private final class HelloTranscriptionNoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
