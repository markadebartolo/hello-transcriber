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

    private let requireOnDevice: Bool

    nonisolated init(requireOnDevice: Bool = false) {
        self.requireOnDevice = requireOnDevice
    }

    func startStreamingSession(
        keyterms: [String],
        onTranscriptUpdate: @escaping @Sendable (String) -> Void,
        onFinalTranscriptReady: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async throws -> any BuddyStreamingTranscriptionSession {
        guard let speechRecognizer = Self.makeBestAvailableSpeechRecognizer(requireOnDevice: requireOnDevice),
              speechRecognizer.isAvailable else {
            throw AppleSpeechTranscriptionProviderError(message: "dictation is not available on this mac.")
        }

        return try AppleSpeechTranscriptionSession(
            speechRecognizer: speechRecognizer,
            requiresOnDeviceRecognition: requireOnDevice || speechRecognizer.supportsOnDeviceRecognition,
            onTranscriptUpdate: onTranscriptUpdate,
            onFinalTranscriptReady: onFinalTranscriptReady,
            onError: onError
        )
    }

    private static func makeBestAvailableSpeechRecognizer(requireOnDevice: Bool) -> SFSpeechRecognizer? {
        let preferredLocales = [
            Locale.autoupdatingCurrent,
            Locale(identifier: "en-US")
        ]

        for preferredLocale in preferredLocales {
            if let speechRecognizer = SFSpeechRecognizer(locale: preferredLocale),
               !requireOnDevice || (speechRecognizer.supportsOnDeviceRecognition && speechRecognizer.isAvailable) {
                return speechRecognizer
            }
        }

        guard let defaultRecognizer = SFSpeechRecognizer(),
              !requireOnDevice || defaultRecognizer.supportsOnDeviceRecognition else { return nil }
        return defaultRecognizer
    }
}

private final class AppleSpeechTranscriptionSession: NSObject, BuddyStreamingTranscriptionSession, SFSpeechRecognitionTaskDelegate, @unchecked Sendable {
    // The audio tap, main actor, and Speech callback may run on different threads.
    // All request/task/state access is serialized, including endAudio/cancel.
    private let lock = NSRecursiveLock()
    private var isCancelled = false
    let finalTranscriptFallbackDelaySeconds: TimeInterval = 1.8

    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest
    private let recognitionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Hello.SpeechCallbacks"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let onTranscriptUpdate: @Sendable (String) -> Void
    private let onFinalTranscriptReady: @Sendable (String) -> Void
    private let onError: @Sendable (Error) -> Void

    private var latestRecognizedText = ""
    private var hasRequestedFinalTranscript = false
    private var hasDeliveredFinalTranscript = false

    init(
        speechRecognizer: SFSpeechRecognizer,
        requiresOnDeviceRecognition: Bool,
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

        recognitionRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition

        // Speech defaults to the main operation queue. Keep provisional-word
        // delivery independent of UI rendering; Buddy performs the actor hop.
        speechRecognizer.queue = recognitionQueue
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
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

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask,
                               didHypothesizeTranscription transcription: SFTranscription) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript else { return }
        // Forward every hypothesis immediately, including revisions of a word.
        latestRecognizedText = transcription.formattedString
        onTranscriptUpdate(latestRecognizedText)
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask,
                               didFinishRecognition result: SFSpeechRecognitionResult) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript else { return }
        latestRecognizedText = result.bestTranscription.formattedString
        onTranscriptUpdate(latestRecognizedText)
        if result.isFinal { deliverFinalTranscriptIfNeeded(latestRecognizedText) }
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript else { return }
        if successfully || (hasRequestedFinalTranscript && !latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            deliverFinalTranscriptIfNeeded(latestRecognizedText)
        } else {
            onError(task.error ?? AppleSpeechTranscriptionProviderError(message: "Speech recognition stopped before finishing."))
        }
    }

    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        lock.lock(); defer { lock.unlock() }
        guard !isCancelled, !hasDeliveredFinalTranscript else { return }
        isCancelled = true
        onError(AppleSpeechTranscriptionProviderError(message: "Speech recognition was interrupted. Please try again."))
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
