//
//  BuddyDictationManager.swift
//  leanring-buddy
//
//  Shared push-to-talk dictation manager for the help chat and brainstorm buddy.
//  Captures microphone audio with AVAudioEngine, routes it into the active
//  transcription provider, and hands the final draft back to the active input bar.
//

import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

enum BuddyPushToTalkShortcut {
    enum ShortcutOption {
        case shiftFunction
        case controlOption
        case shiftControl
        case controlOptionSpace
        case shiftControlSpace

        var displayText: String {
            switch self {
            case .shiftFunction:
                return "shift + fn"
            case .controlOption:
                return "ctrl + option"
            case .shiftControl:
                return "shift + control"
            case .controlOptionSpace:
                return "ctrl + option + space"
            case .shiftControlSpace:
                return "shift + control + space"
            }
        }

        /// Spoken in voice narration — no "+" so it never sounds like a plus key.
        var spokenHoldPhrase: String {
            switch self {
            case .shiftFunction:
                return "Hold the Shift and Function keys"
            case .controlOption:
                return "Hold the Control and Option keys"
            case .shiftControl:
                return "Hold the Shift and Control keys"
            case .controlOptionSpace:
                return "Hold the Control and Option keys, then press Space"
            case .shiftControlSpace:
                return "Hold the Shift and Control keys, then press Space"
            }
        }

        /// Short panel hint — readable, no plus signs.
        var panelHintPhrase: String {
            switch self {
            case .shiftFunction:
                return "Hold the Shift and Function keys to talk."
            case .controlOption:
                return "Hold the Control and Option keys to talk."
            case .shiftControl:
                return "Hold the Shift and Control keys to talk."
            case .controlOptionSpace:
                return "Hold the Control and Option keys, then press Space to talk."
            case .shiftControlSpace:
                return "Hold the Shift and Control keys, then press Space to talk."
            }
        }

        /// Lowercase streamed onboarding prompt beside the fin.
        var onboardingNamePromptPhrase: String {
            switch self {
            case .shiftFunction:
                return "hold the shift and function keys and tell me your name"
            case .controlOption:
                return "hold the control and option keys and tell me your name"
            case .shiftControl:
                return "hold the shift and control keys and tell me your name"
            case .controlOptionSpace:
                return "hold the control and option keys, press space, and tell me your name"
            case .shiftControlSpace:
                return "hold the shift and control keys, press space, and tell me your name"
            }
        }

        var keyCapsuleLabels: [String] {
            switch self {
            case .shiftFunction:
                return ["shift", "fn"]
            case .controlOption:
                return ["ctrl", "option"]
            case .shiftControl:
                return ["shift", "control"]
            case .controlOptionSpace:
                return ["ctrl", "option", "space"]
            case .shiftControlSpace:
                return ["shift", "control", "space"]
            }
        }

        fileprivate var modifierOnlyFlags: NSEvent.ModifierFlags? {
            switch self {
            case .shiftFunction:
                return [.shift, .function]
            case .controlOption:
                return [.control, .option]
            case .shiftControl:
                return [.shift, .control]
            case .controlOptionSpace, .shiftControlSpace:
                return nil
            }
        }

        fileprivate var spaceShortcutModifierFlags: NSEvent.ModifierFlags? {
            switch self {
            case .shiftFunction:
                return nil
            case .controlOption:
                return nil
            case .shiftControl:
                return nil
            case .controlOptionSpace:
                return [.control, .option]
            case .shiftControlSpace:
                return [.shift, .control]
            }
        }
    }

    enum ShortcutTransition {
        case none
        case pressed
        case released
    }

    private enum ShortcutEventType {
        case flagsChanged
        case keyDown
        case keyUp
    }

    static let currentShortcutOption: ShortcutOption = .controlOption
    static let pushToTalkKeyCode: UInt16 = 49 // Space
    static let pushToTalkDisplayText = currentShortcutOption.displayText
    static let pushToTalkSpokenHoldPhrase = currentShortcutOption.spokenHoldPhrase
    static let pushToTalkPanelHintPhrase = currentShortcutOption.panelHintPhrase
    static let pushToTalkOnboardingNamePromptPhrase = currentShortcutOption.onboardingNamePromptPhrase
    static let pushToTalkTooltipText = "push to talk (\(pushToTalkDisplayText))"

    static func shortcutTransition(
        for event: NSEvent,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        guard let shortcutEventType = shortcutEventType(for: event.type) else { return .none }

        return shortcutTransition(
            for: shortcutEventType,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask),
            wasShortcutPreviouslyPressed: wasShortcutPreviouslyPressed
        )
    }

    static func shortcutTransition(
        for eventType: CGEventType,
        keyCode: UInt16,
        modifierFlagsRawValue: UInt64,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        guard let shortcutEventType = shortcutEventType(for: eventType) else { return .none }

        return shortcutTransition(
            for: shortcutEventType,
            keyCode: keyCode,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(modifierFlagsRawValue))
                .intersection(.deviceIndependentFlagsMask),
            wasShortcutPreviouslyPressed: wasShortcutPreviouslyPressed
        )
    }

    private static func shortcutEventType(for eventType: NSEvent.EventType) -> ShortcutEventType? {
        switch eventType {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }

    private static func shortcutEventType(for eventType: CGEventType) -> ShortcutEventType? {
        switch eventType {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }

    private static func shortcutTransition(
        for shortcutEventType: ShortcutEventType,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        if let modifierOnlyFlags = currentShortcutOption.modifierOnlyFlags {
            guard shortcutEventType == .flagsChanged else { return .none }

            let isShortcutCurrentlyPressed = modifierFlags.contains(modifierOnlyFlags)

            if isShortcutCurrentlyPressed && !wasShortcutPreviouslyPressed {
                return .pressed
            }

            if !isShortcutCurrentlyPressed && wasShortcutPreviouslyPressed {
                return .released
            }

            return .none
        }

        guard let pushToTalkModifierFlags = currentShortcutOption.spaceShortcutModifierFlags else {
            return .none
        }

        let matchesModifierFlags = modifierFlags.isSuperset(of: pushToTalkModifierFlags)

        if shortcutEventType == .keyDown
            && keyCode == pushToTalkKeyCode
            && matchesModifierFlags
            && !wasShortcutPreviouslyPressed {
            return .pressed
        }

        if shortcutEventType == .keyUp
            && keyCode == pushToTalkKeyCode
            && wasShortcutPreviouslyPressed {
            return .released
        }

        return .none
    }
}

enum BuddyDictationPermissionProblem {
    case microphoneAccessDenied
    case speechRecognitionDenied
}

private enum BuddyDictationStartSource {
    case microphoneButton
    case keyboardShortcut
    case alwaysOnListening
}

private struct BuddyDictationDraftCallbacks {
    let updateDraftText: (String) -> Void
    let submitDraftText: (String) -> Void
}

@MainActor
final class BuddyDictationManager: NSObject, ObservableObject {
    private static let defaultFinalTranscriptFallbackDelaySeconds: TimeInterval = 2.4
    private static let recordedAudioPowerHistoryLength = 44
    private static let recordedAudioPowerHistoryBaselineLevel: CGFloat = 0.02
    private static let recordedAudioPowerHistorySampleIntervalSeconds: TimeInterval = 0.07

    @Published private(set) var isRecordingFromMicrophoneButton = false
    @Published private(set) var isRecordingFromKeyboardShortcut = false
    @Published private(set) var isRecordingFromAlwaysOn = false
    @Published private(set) var isKeyboardShortcutSessionActiveOrFinalizing = false
    @Published private(set) var isFinalizingTranscript = false
    @Published private(set) var isPreparingToRecord = false
    @Published private(set) var currentAudioPowerLevel: CGFloat = 0
    @Published private(set) var recordedAudioPowerHistory = Array(
        repeating: BuddyDictationManager.recordedAudioPowerHistoryBaselineLevel,
        count: BuddyDictationManager.recordedAudioPowerHistoryLength
    )
    @Published private(set) var microphoneButtonRecordingStartedAt: Date?
    @Published private(set) var transcriptionProviderDisplayName = ""
    @Published var lastErrorMessage: String?
    @Published private(set) var currentPermissionProblem: BuddyDictationPermissionProblem?

    var isDictationInProgress: Bool {
        isPreparingToRecord || isRecordingFromMicrophoneButton || isRecordingFromKeyboardShortcut
            || isRecordingFromAlwaysOn || isFinalizingTranscript
    }

    var isActivelyRecordingAudio: Bool {
        isRecordingFromMicrophoneButton || isRecordingFromKeyboardShortcut || isRecordingFromAlwaysOn
    }

    var isMicrophoneButtonActivelyRecordingAudio: Bool {
        isRecordingFromMicrophoneButton
    }

    var isMicrophoneButtonSessionBusy: Bool {
        activeStartSource == .microphoneButton
            && (isPreparingToRecord || isRecordingFromMicrophoneButton || isFinalizingTranscript)
    }

    var needsInitialPermissionPrompt: Bool {
        if transcriptionProvider.requiresSpeechRecognitionPermission {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
                || SFSpeechRecognizer.authorizationStatus() == .notDetermined
        }

        return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
    }

    private var transcriptionProvider: any BuddyTranscriptionProvider
    private let audioCapture: any BuddyAudioCapture
    private let permissionCheck: (@MainActor () async -> Bool)?
    private var activeTranscriptionSession: (any BuddyStreamingTranscriptionSession)?
    private var recordingLimitTask: Task<Void, Never>?
    private var activeStartSource: BuddyDictationStartSource?
    private var draftCallbacks: BuddyDictationDraftCallbacks?
    private var draftTextBeforeCurrentDictation = ""
    private var latestRecognizedText = ""
    private var shouldAutomaticallySubmitFinalDraft = false
    private var hasFinishedCurrentDictationSession = false
    private var finalizeFallbackWorkItem: DispatchWorkItem?
    private var pendingStartRequestIdentifier = UUID()
    private var lastRecordedAudioPowerSampleDate = Date.distantPast
    private var activePermissionRequestTask: Task<Bool, Never>?
    /// Timestamp of the last completed permission request, used to debounce
    /// rapid follow-up requests that arrive before macOS updates its cache.
    private var lastPermissionRequestCompletedAt: Date?

    init(
        transcriptionProvider: any BuddyTranscriptionProvider = BuddyTranscriptionProviderFactory.makeDefaultProvider(),
        audioCapture: any BuddyAudioCapture = BuddyMicrophoneCapture(),
        permissionCheck: (@MainActor () async -> Bool)? = nil
    ) {
        self.transcriptionProvider = transcriptionProvider
        self.audioCapture = audioCapture
        self.permissionCheck = permissionCheck
        self.transcriptionProviderDisplayName = transcriptionProvider.displayName
        super.init()
    }

    func configureTranscriptionProvider(_ provider: any BuddyTranscriptionProvider) {
        guard !isDictationInProgress else { return }
        transcriptionProvider = provider
        transcriptionProviderDisplayName = provider.displayName
    }

    func startPersistentDictationFromMicrophoneButton(
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void
    ) async {
        await startPushToTalk(
            startSource: .microphoneButton,
            currentDraftText: currentDraftText,
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText,
            shouldAutomaticallySubmitFinalDraftOnStop: false
        )
    }

    func startPushToTalkFromKeyboardShortcut(
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void
    ) async {
        await startPushToTalk(
            startSource: .keyboardShortcut,
            currentDraftText: currentDraftText,
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText,
            shouldAutomaticallySubmitFinalDraftOnStop: currentDraftText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }

    /// Always-on (hands-free) mode: the coordinator's voice-activity detector calls this when
    /// it hears speech onset. Runs the exact same proven capture+transcribe flow as the
    /// hotkey, but auto-submits the finalized transcript (which the coordinator routes). The
    /// existing empty-transcript guard in `finishCurrentDictationSessionIfNeeded` means pure
    /// silence/noise never submits — so dead space never triggers anything.
    func startAlwaysOnUtterance(submitTranscript: @escaping (String) -> Void) async {
        await startPushToTalk(
            startSource: .alwaysOnListening,
            currentDraftText: "",
            updateDraftText: { _ in },
            submitDraftText: submitTranscript,
            shouldAutomaticallySubmitFinalDraftOnStop: true
        )
    }

    /// Ends the current always-on utterance (silence detected, or the mode is turning off),
    /// finalizing the transcript so it routes.
    func stopAlwaysOnUtterance() {
        stopPushToTalk(expectedStartSource: .alwaysOnListening)
    }

    func stopPersistentDictationFromMicrophoneButton() {
        stopPushToTalk(expectedStartSource: .microphoneButton)
    }

    func stopPushToTalkFromKeyboardShortcut() {
        stopPushToTalk(expectedStartSource: .keyboardShortcut)
    }

    func cancelCurrentDictation(preserveDraftText: Bool = true) {
        pendingStartRequestIdentifier = UUID()

        guard isDictationInProgress else { return }

        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil

        if preserveDraftText {
            let currentDraftText = composeDraftText(withTranscribedText: latestRecognizedText)
            draftCallbacks?.updateDraftText(currentDraftText)
        }

        audioCapture.stop()
        activeTranscriptionSession?.cancel()

        resetSessionState()
    }

    private func startPushToTalk(
        startSource: BuddyDictationStartSource,
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void,
        shouldAutomaticallySubmitFinalDraftOnStop: Bool
    ) async {
        guard !Task.isCancelled, !isDictationInProgress else { return }
        // Claim this generation before any suspension; a cancelled start must never
        // reset a newer session that began while a permission/provider await resumed.
        let startRequestIdentifier = UUID()
        pendingStartRequestIdentifier = startRequestIdentifier
        activeStartSource = startSource
        lastErrorMessage = nil
        currentPermissionProblem = nil
        isPreparingToRecord = true

        let hasPermissions: Bool
        if let permissionCheck {
            hasPermissions = await permissionCheck()
        } else {
            hasPermissions = await requestMicrophoneAndSpeechPermissionsWithoutDuplicatePrompts()
        }
        guard pendingStartRequestIdentifier == startRequestIdentifier else { return }
        guard hasPermissions, !Task.isCancelled else {
            resetSessionState()
            return
        }

        draftTextBeforeCurrentDictation = currentDraftText
        latestRecognizedText = ""
        draftCallbacks = BuddyDictationDraftCallbacks(
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText
        )
        activeStartSource = startSource
        shouldAutomaticallySubmitFinalDraft = shouldAutomaticallySubmitFinalDraftOnStop
        hasFinishedCurrentDictationSession = false
        isFinalizingTranscript = false
        isRecordingFromMicrophoneButton = startSource == .microphoneButton
        isRecordingFromKeyboardShortcut = startSource == .keyboardShortcut
        isRecordingFromAlwaysOn = startSource == .alwaysOnListening
        isKeyboardShortcutSessionActiveOrFinalizing = startSource == .keyboardShortcut
        currentAudioPowerLevel = 0
        recordedAudioPowerHistory = Array(
            repeating: Self.recordedAudioPowerHistoryBaselineLevel,
            count: Self.recordedAudioPowerHistoryLength
        )
        microphoneButtonRecordingStartedAt = nil
        lastRecordedAudioPowerSampleDate = .distantPast

        guard !Task.isCancelled else {
            DorsalLog("🎙️ BuddyDictationManager: start cancelled (shortcut released before recording began)")
            resetSessionState()
            return
        }

        do {
            try await startRecognitionSession(identifier: startRequestIdentifier)
            guard pendingStartRequestIdentifier == startRequestIdentifier else { return }
            guard !Task.isCancelled else {
                cancelCurrentDictation(preserveDraftText: false)
                return
            }
            if startSource == .microphoneButton {
                microphoneButtonRecordingStartedAt = Date()
            }
            isPreparingToRecord = false
            // Bound capture if the OS loses a release event or a speech callback.
            recordingLimitTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self,
                      self.pendingStartRequestIdentifier == startRequestIdentifier else { return }
                self.stopPushToTalk(expectedStartSource: startSource)
            }
        } catch {
            guard pendingStartRequestIdentifier == startRequestIdentifier else { return }
            lastErrorMessage = userFacingErrorMessage(from: error, fallback: "Couldn't start voice input. Try again.")
            cancelCurrentDictation(preserveDraftText: false)
        }
    }

    private func stopPushToTalk(expectedStartSource: BuddyDictationStartSource) {
        guard activeStartSource == expectedStartSource else { return }
        // A quick release during startup discards that attempt, even when its
        // provider ignores Task cancellation and returns a session later.
        if isPreparingToRecord {
            cancelCurrentDictation(preserveDraftText: false)
            return
        }
        guard !isFinalizingTranscript else { return }
        isRecordingFromMicrophoneButton = false
        isRecordingFromKeyboardShortcut = false
        isRecordingFromAlwaysOn = false
        isFinalizingTranscript = true
        recordingLimitTask?.cancel()
        audioCapture.stop()
        activeTranscriptionSession?.requestFinalTranscript()
        let identifier = pendingStartRequestIdentifier
        let delay = activeTranscriptionSession?.finalTranscriptFallbackDelaySeconds
            ?? Self.defaultFinalTranscriptFallbackDelaySeconds
        finalizeFallbackWorkItem?.cancel()
        let fallbackWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.pendingStartRequestIdentifier == identifier,
                      self.isFinalizingTranscript else { return }
                self.finishCurrentDictationSessionIfNeeded(
                    shouldSubmitFinalDraft: self.shouldAutomaticallySubmitFinalDraft
                )
            }
        }
        finalizeFallbackWorkItem = fallbackWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fallbackWorkItem)
    }

    private func startRecognitionSession(identifier: UUID) async throws {
        // Apple Speech has no remote provider handshake. Prepare its request before
        // starting the mic so no borrowed AVAudioEngine buffers escape the tap.
        let session = try await transcriptionProvider.startStreamingSession(
            keyterms: buildTranscriptionKeyterms(),
            onTranscriptUpdate: { [weak self] text in
                Task { @MainActor in
                    guard let self, self.pendingStartRequestIdentifier == identifier else { return }
                    self.latestRecognizedText = text
                    self.draftCallbacks?.updateDraftText(text)
                }
            },
            onFinalTranscriptReady: { [weak self] text in
                Task { @MainActor in
                    guard let self, self.pendingStartRequestIdentifier == identifier else { return }
                    self.latestRecognizedText = text
                    // Apple may end recognition before key release (service limit).
                    self.finishCurrentDictationSessionIfNeeded(
                        shouldSubmitFinalDraft: self.shouldAutomaticallySubmitFinalDraft
                    )
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    guard let self, self.pendingStartRequestIdentifier == identifier else { return }
                    self.handleRecognitionError(error)
                }
            }
        )
        guard pendingStartRequestIdentifier == identifier, !Task.isCancelled else {
            session.cancel()
            return
        }
        activeTranscriptionSession = session
        try audioCapture.start { [weak self, session] buffer in
            session.appendAudioBuffer(buffer)
            let level = Self.audioPowerLevel(from: buffer)
            Task { @MainActor in
                guard let self, self.pendingStartRequestIdentifier == identifier,
                      self.isActivelyRecordingAudio else { return }
                self.updateAudioPowerLevel(level)
            }
        }
    }

    private func handleRecognitionError(_ error: Error) {
        if hasFinishedCurrentDictationSession {
            return
        }

        if isFinalizingTranscript && !latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finishCurrentDictationSessionIfNeeded(
                shouldSubmitFinalDraft: shouldAutomaticallySubmitFinalDraft
            )
        } else {
            DorsalLog("❌ Buddy dictation error (\(transcriptionProvider.displayName)): \(error)")
            lastErrorMessage = userFacingErrorMessage(
                from: error,
                fallback: "couldn't transcribe that. try again."
            )
            cancelCurrentDictation(preserveDraftText: false)
        }
    }

    private func finishCurrentDictationSessionIfNeeded(shouldSubmitFinalDraft: Bool) {
        guard !hasFinishedCurrentDictationSession else { return }
        hasFinishedCurrentDictationSession = true

        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil

        let finalDraftText = composeDraftText(withTranscribedText: latestRecognizedText)
        let finalTranscriptText = latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDraftCallbacks = draftCallbacks

        if !shouldSubmitFinalDraft && !finalDraftText.isEmpty {
            currentDraftCallbacks?.updateDraftText(finalDraftText)
        }

        audioCapture.stop()
        activeTranscriptionSession?.cancel()

        resetSessionState()

        guard shouldSubmitFinalDraft else { return }
        guard !finalTranscriptText.isEmpty else { return }

        currentDraftCallbacks?.submitDraftText(finalDraftText)
    }

    private func composeDraftText(withTranscribedText transcribedText: String) -> String {
        let trimmedTranscriptText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTranscriptText.isEmpty else {
            return draftTextBeforeCurrentDictation
        }

        let trimmedExistingDraftText = draftTextBeforeCurrentDictation
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedExistingDraftText.isEmpty else {
            return trimmedTranscriptText
        }

        if draftTextBeforeCurrentDictation.hasSuffix(" ") || draftTextBeforeCurrentDictation.hasSuffix("\n") {
            return draftTextBeforeCurrentDictation + trimmedTranscriptText
        }

        return draftTextBeforeCurrentDictation + " " + trimmedTranscriptText
    }

    private func resetSessionState() {
        pendingStartRequestIdentifier = UUID()
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        activeTranscriptionSession = nil
        draftCallbacks = nil
        activeStartSource = nil
        draftTextBeforeCurrentDictation = ""
        latestRecognizedText = ""
        shouldAutomaticallySubmitFinalDraft = false
        hasFinishedCurrentDictationSession = false
        isPreparingToRecord = false
        isRecordingFromMicrophoneButton = false
        isRecordingFromKeyboardShortcut = false
        isRecordingFromAlwaysOn = false
        isKeyboardShortcutSessionActiveOrFinalizing = false
        isFinalizingTranscript = false
        currentAudioPowerLevel = 0
        recordedAudioPowerHistory = Array(
            repeating: Self.recordedAudioPowerHistoryBaselineLevel,
            count: Self.recordedAudioPowerHistoryLength
        )
        microphoneButtonRecordingStartedAt = nil
        lastRecordedAudioPowerSampleDate = .distantPast
    }

    private func buildTranscriptionKeyterms() -> [String] {
        let baseKeyterms = ["Hello"]

        let combinedKeyterms = baseKeyterms
        var uniqueNormalizedKeyterms = Set<String>()
        var orderedKeyterms: [String] = []

        for keyterm in combinedKeyterms {
            let trimmedKeyterm = keyterm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKeyterm.isEmpty else { continue }

            let normalizedKeyterm = trimmedKeyterm.lowercased()
            if uniqueNormalizedKeyterms.contains(normalizedKeyterm) {
                continue
            }

            uniqueNormalizedKeyterms.insert(normalizedKeyterm)
            orderedKeyterms.append(trimmedKeyterm)
        }

        return orderedKeyterms
    }

    nonisolated private static func audioPowerLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        return CGFloat(min(max(sqrt(sum / Float(buffer.frameLength)) * 10.2, 0), 1))
    }

    private func updateAudioPowerLevel(_ level: CGFloat) {
        currentAudioPowerLevel = max(level, currentAudioPowerLevel * 0.72)
        let now = Date()
        if now.timeIntervalSince(lastRecordedAudioPowerSampleDate) >= Self.recordedAudioPowerHistorySampleIntervalSeconds {
            lastRecordedAudioPowerSampleDate = now
            appendRecordedAudioPowerSample(max(level, Self.recordedAudioPowerHistoryBaselineLevel))
        }
    }

    private func appendRecordedAudioPowerSample(_ audioPowerSample: CGFloat) {
        var updatedRecordedAudioPowerHistory = recordedAudioPowerHistory
        updatedRecordedAudioPowerHistory.append(audioPowerSample)

        if updatedRecordedAudioPowerHistory.count > Self.recordedAudioPowerHistoryLength {
            updatedRecordedAudioPowerHistory.removeFirst(
                updatedRecordedAudioPowerHistory.count - Self.recordedAudioPowerHistoryLength
            )
        }

        recordedAudioPowerHistory = updatedRecordedAudioPowerHistory
    }

    private func requestMicrophoneAndSpeechPermissionsIfNeeded() async -> Bool {
        let hasMicrophonePermission = await requestMicrophonePermissionIfNeeded()
        guard hasMicrophonePermission else {
            lastErrorMessage = "microphone permission is required for push to talk."
            return false
        }

        guard transcriptionProvider.requiresSpeechRecognitionPermission else {
            return true
        }

        let hasSpeechRecognitionPermission = await requestSpeechRecognitionPermissionIfNeeded()
        guard hasSpeechRecognitionPermission else {
            lastErrorMessage = "speech recognition permission is required for push to talk."
            return false
        }

        return true
    }

    /// macOS can show the microphone/speech sheet again if we accidentally fan out
    /// multiple permission requests before the first one finishes. We keep exactly
    /// one in-flight request task so rapid repeat presses all await the same result.
    ///
    /// After the task completes, we skip re-requesting for a short cooldown period
    /// so macOS has time to update its authorization cache. This prevents the
    /// permission dialog from popping up again on rapid follow-up presses.
    private func requestMicrophoneAndSpeechPermissionsWithoutDuplicatePrompts() async -> Bool {
        // If a permission request is already in-flight, reuse it.
        if let activePermissionRequestTask {
            return await activePermissionRequestTask.value
        }

        // If we just finished a permission request very recently, skip re-requesting.
        // macOS can briefly report .notDetermined even after the user tapped Allow,
        // so we trust the cached result for a short window.
        if let lastPermissionRequestCompletedAt,
           Date().timeIntervalSince(lastPermissionRequestCompletedAt) < 1.0 {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
                && (!transcriptionProvider.requiresSpeechRecognitionPermission
                    || SFSpeechRecognizer.authorizationStatus() == .authorized)
        }

        let permissionRequestTask = Task { @MainActor in
            await self.requestMicrophoneAndSpeechPermissionsIfNeeded()
        }

        activePermissionRequestTask = permissionRequestTask

        let hasPermissions = await permissionRequestTask.value
        activePermissionRequestTask = nil
        lastPermissionRequestCompletedAt = Date()
        return hasPermissions
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            currentPermissionProblem = nil
            return true
        case .notDetermined:
            let isGranted = await BuddyPermissionBridge.request { completion in
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
            }
            currentPermissionProblem = isGranted ? nil : .microphoneAccessDenied
            return isGranted
        case .denied, .restricted:
            currentPermissionProblem = .microphoneAccessDenied
            return false
        @unknown default:
            currentPermissionProblem = .microphoneAccessDenied
            return false
        }
    }

    private func requestSpeechRecognitionPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            currentPermissionProblem = nil
            return true
        case .notDetermined:
            let isGranted = await BuddyPermissionBridge.request { completion in
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    completion(status == .authorized)
                }
            }
            currentPermissionProblem = isGranted ? nil : .speechRecognitionDenied
            return isGranted
        case .denied, .restricted:
            currentPermissionProblem = .speechRecognitionDenied
            return false
        @unknown default:
            currentPermissionProblem = .speechRecognitionDenied
            return false
        }
    }

    func openRelevantPrivacySettings() {
        let settingsURLString: String

        switch currentPermissionProblem {
        case .microphoneAccessDenied:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognitionDenied:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case nil:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security"
        }

        guard let settingsURL = URL(string: settingsURLString) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    private func userFacingErrorMessage(from error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !errorDescription.isEmpty {
            return errorDescription
        }

        let errorDescription = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !errorDescription.isEmpty,
           errorDescription != "The operation couldn’t be completed." {
            return errorDescription
        }

        return fallback
    }
}

/// Injectable capture boundary for lifecycle tests; production uses the original
/// AVAudioEngine/input-node tap pipeline. The tap consumes buffers synchronously.
@MainActor
protocol BuddyAudioCapture: AnyObject {
    func start(consume: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws
    func stop()
}

@MainActor
final class BuddyMicrophoneCapture: BuddyAudioCapture {
    private let engine = AVAudioEngine()
    private var hasTap = false

    func start(consume: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        stop()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AppleSpeechTranscriptionProviderError(message: "No microphone is available. Check your audio input in System Settings.")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format,
                         block: Self.makeTapHandler(consume: consume))
        hasTap = true
        do {
            engine.prepare()
            try engine.start()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        engine.stop()
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
    }

    // AVAudioNodeTapBlock is a legacy non-Sendable SDK callback. Creating it
    // inline in start() inherits MainActor and traps on the first audio buffer.
    // Keep the actual production handler explicitly nonisolated and Sendable;
    // borrowed buffers are consumed synchronously on the audio callback queue.
    nonisolated static func makeTapHandler(
        consume: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in consume(buffer) }
    }
}

/// TCC completes on a background queue. Keep callback registration nonisolated
/// and explicitly Sendable, then resume the awaiting actor via continuation.
/// Inferring MainActor on a legacy SDK completion can trap at runtime in Swift 6.
enum BuddyPermissionBridge {
    static func request<Value: Sendable>(
        _ register: @Sendable (@escaping @Sendable (Value) -> Void) -> Void
    ) async -> Value {
        await withCheckedContinuation { continuation in
            register { value in continuation.resume(returning: value) }
        }
    }
}
