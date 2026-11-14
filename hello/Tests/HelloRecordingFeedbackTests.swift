@main
struct HelloRecordingFeedbackTests {
    static func main() {
        func state(held: Bool = false, starting: Bool = false, recording: Bool = false,
                   finalizing: Bool = false, processing: Bool = false, result: Bool = false) -> HelloRecordingFeedback {
            HelloRecordingFeedback(shortcutHeld: held, starting: starting, recording: recording,
                                   finalizing: finalizing, processing: processing, showingResult: result)
        }
        precondition(!state().isVisible)
        precondition(state(held: true, starting: true).phase == .starting)
        precondition(!state(held: true, starting: true, recording: true).showsLiveWaveform,
                     "Startup flags must not claim a live microphone before preparation finishes")
        precondition(state(held: true, recording: true).showsLiveWaveform)
        // A failed/ended speech session while the keys remain held must stay
        // visible without falsely indicating that audio is still being captured.
        let stoppedWhileHeld = state(held: true)
        precondition(stoppedWhileHeld.isVisible && stoppedWhileHeld.phase == .stopped)
        precondition(!stoppedWhileHeld.showsLiveWaveform)
        precondition(state(finalizing: true).phase == .transcribing)
        precondition(state(processing: true).isVisible)
        precondition(state(result: true).phase == .result)
        precondition(state(held: true, result: true).phase == .stopped,
                     "Result-toast expiry must not hide a held shortcut")
        precondition(!state().showsLiveWaveform)
        print("Hello recording feedback: held-key, startup, stopped, finalizing and result transitions passed")
    }
}
