//
//  AppleSpeechTranscriptionProvider.swift
//  leanring-buddy
//
//  Local fallback transcription provider backed by Apple's Speech framework.
//

import AVFoundation
import Foundation
import Speech

struct AppleSpeechTranscriptionProviderError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

final class AppleSpeechTranscriptionProvider: BuddyTranscriptionProvider {
    let displayName = "Apple Speech"
    let requiresSpeechRecognitionPermission = true
    let isConfigured = true
    let unavailableExplanation: String? = nil

    func startStreamingSession(
        keyterms: [String],
        onTranscriptUpdate: @escaping @Sendable (String) -> Void,
        onFinalTranscriptReady: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async throws -> any BuddyStreamingTranscriptionSession {
        guard let speechRecognizer = Self.makeBestAvailableSpeechRecognizer(), speechRecognizer.isAvailable else {
            throw AppleSpeechTranscriptionProviderError(message: "dictation is not available on this mac.")
        }

        return try AppleSpeechTranscriptionSession(
            speechRecognizer: speechRecognizer,
            onTranscriptUpdate: onTranscriptUpdate,
            onFinalTranscriptReady: onFinalTranscriptReady,
            onError: onError
        )
    }

    private static func makeBestAvailableSpeechRecognizer() -> SFSpeechRecognizer? {
        let preferredLocales = [
            Locale.autoupdatingCurrent,
            Locale(identifier: "en-US")
        ]

        for preferredLocale in preferredLocales {
            if let speechRecognizer = SFSpeechRecognizer(locale: preferredLocale) {
                return speechRecognizer
            }
        }

        return SFSpeechRecognizer()
    }
}

private final class AppleSpeechTranscriptionSession: NSObject, BuddyStreamingTranscriptionSession, @unchecked Sendable {
    // The audio tap, main actor, and Speech callback may run on different threads.
    // All request/task/state access is serialized, including endAudio/cancel.
    private let lock = NSRecursiveLock()
    private var isCancelled = false
    let finalTranscriptFallbackDelaySeconds: TimeInterval = 1.8

    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest
    private var recognitionTask: SFSpeechRecognitionTask?
    private let onTranscriptUpdate: @Sendable (String) -> Void
    private let onFinalTranscriptReady: @Sendable (String) -> Void
    private let onError: @Sendable (Error) -> Void

    private var latestRecognizedText = ""
    private var hasRequestedFinalTranscript = false
    private var hasDeliveredFinalTranscript = false

    init(
        speechRecognizer: SFSpeechRecognizer,
        onTranscriptUpdate: @escaping @Sendable (String) -> Void,
        onFinalTranscriptReady: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) throws {
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        self.onTranscriptUpdate = onTranscriptUpdate
        self.onFinalTranscriptReady = onFinalTranscriptReady
        self.onError = onError

        super.init()

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.addsPunctuation = true

        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionEvent(result: result, error: error)
        }
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript, !hasRequestedFinalTranscript else { return }
        recognitionRequest.append(audioBuffer)
    }

    func requestFinalTranscript() {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasRequestedFinalTranscript else { return }
        hasRequestedFinalTranscript = true
        recognitionRequest.endAudio()
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        isCancelled = true
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func handleRecognitionEvent(
        result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript else { return }
        if let result {
            latestRecognizedText = result.bestTranscription.formattedString
            onTranscriptUpdate(latestRecognizedText)

            if result.isFinal {
                deliverFinalTranscriptIfNeeded(latestRecognizedText)
                return
            }
        }

        guard let error else { return }

        if hasRequestedFinalTranscript && !latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deliverFinalTranscriptIfNeeded(latestRecognizedText)
        } else {
            onError(error)
        }
    }

    private func deliverFinalTranscriptIfNeeded(_ transcriptText: String) {
        guard !hasDeliveredFinalTranscript else { return }
        hasDeliveredFinalTranscript = true
        onFinalTranscriptReady(transcriptText)
    }

    deinit {
        cancel()
    }
}
