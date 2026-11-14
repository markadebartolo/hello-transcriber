/// Display the newest recognized word immediately, without a delayed playback
/// queue. Grapheme indexing keeps accents and emoji intact when coloring a letter.
struct HelloLiveWord {
    let word: String
    let before: String
    let focus: String
    let after: String

    init(_ transcript: String) {
        word = transcript.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        let characters = Array(word)
        let letters = characters.indices.filter { characters[$0].isLetter || characters[$0].isNumber }
        let offset: Int
        switch letters.count {
        case 0...1: offset = 0
        case 2...5: offset = 1
        case 6...9: offset = 2
        case 10...13: offset = 3
        default: offset = 4
        }
        if letters.isEmpty {
            before = ""; focus = ""; after = word
        } else {
            let index = letters[offset]
            before = String(characters[..<index])
            focus = String(characters[index])
            after = String(characters[(index + 1)...])
        }
    }
}

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
