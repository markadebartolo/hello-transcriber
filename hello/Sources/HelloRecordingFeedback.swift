/// Presentation follows both the physical shortcut and the audio lifecycle.
/// A held shortcut must never imply that a stopped microphone is still listening.
struct HelloRecordingFeedback {
    enum Phase { case hidden, starting, listening, transcribing, processing, stopped, result }

    let phase: Phase

    init(shortcutHeld: Bool, starting: Bool, recording: Bool, finalizing: Bool,
         processing: Bool, showingResult: Bool) {
        if starting { phase = .starting }
        else if recording { phase = .listening }
        else if finalizing { phase = .transcribing }
        else if processing { phase = .processing }
        else if shortcutHeld { phase = .stopped }
        else if showingResult { phase = .result }
        else { phase = .hidden }
    }

    var isVisible: Bool { phase != .hidden }
    var showsLiveWaveform: Bool { phase == .listening }
    var title: String {
        switch phase {
        case .starting: return "Starting microphone…"
        case .listening: return "Listening"
        case .transcribing: return "Transcribing…"
        case .processing: return "Processing…"
        case .stopped: return "Microphone stopped"
        case .result, .hidden: return "hello"
        }
    }
}
