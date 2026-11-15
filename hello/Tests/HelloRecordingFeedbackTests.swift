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
        precondition(HelloLiveCaption("one two three four").text == "two three four")
        precondition(HelloLiveCaption("Maya Chan").text == "Maya Chan")
        precondition(HelloLiveCaption("Maya Chen").text == "Maya Chen")
        precondition(HelloLiveCaption(" \n\t").text.isEmpty)
        precondition(HelloLiveCaption("hello\n café  😊").text == "hello café 😊")
        precondition(HelloLiveCaption("$15 isn't $50").text == "$15 isn't $50")
        print("Hello recording feedback: held-key, startup, stopped, finalizing and result transitions passed")
        print("Hello live caption: three-word limit, revisions, whitespace, numbers and Unicode cases passed")
    }
}
