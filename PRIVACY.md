# Privacy

Hello captures microphone audio only during an explicit push-to-talk session.
There is no always-listening product mode, telemetry, account, license server,
screenshot capture, private Dorsal service, or embedded API credential.

Audio buffers go to Apple's Speech framework. Hello sets
[`requiresOnDeviceRecognition`](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
when the selected recognizer reports
[`supportsOnDeviceRecognition`](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition).
When on-device recognition is unsupported, Apple may receive audio for processing;
network access/service availability may be required. When on-device recognition is
required but fails, Hello reports a failure rather than silently retrying remotely.
The recognition language follows the Mac's locale, with en-US as a fallback when
no recognizer can be constructed. Locale support does not guarantee availability.
Apple controls its service's handling/retention; Hello does not make a claim that
Apple stores nothing. Speech authorization is required even for on-device requests.
See [Apple's authorization documentation](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).

Optional punctuation cleanup runs through the on-device
[Foundation Models framework](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).
Hello sends it only the transcript, not text from the destination field. No external
LLM API is called. The proposal is review-only, never automatically inserted.

Accessibility reads the original app, focused element, text value and selection
in memory to verify that insertion is still safe. Secure Input and secure text
fields are excluded. Hello only writes AX selected text after revalidation; it
never generates Return/Send. An external application's Accessibility API cannot
provide an atomic compare-and-set transaction, so insertion is best effort and
unsupported/ambiguous fields fall back to Copy. Avoid editing or switching focus
while finishing a dictation.

Input Monitoring/listen-only event taps detect shortcut transitions, Escape and
interactions that invalidate a destination; Hello does not store keystrokes. It
never requests Screen Recording, Camera, contacts, location or Automation access.

Hello writes no audio or transcript history to disk and logs no transcript content.
Latest text and destination snapshots are held in process memory during use and
removed on Clear/cancel/quit or when replaced by a new session. Copy places text on
the macOS clipboard at your request; other apps and clipboard managers may retain
it. Your preferences and macOS privacy grants are managed locally. OS crash reports,
swap and Apple's own diagnostics are outside Hello's storage policy.

Revoke access in System Settings → Privacy & Security. Delete Hello.app to uninstall.
