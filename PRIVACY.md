# Privacy

Hello captures microphone audio only during an explicit push-to-talk session.
There is no always-listening product mode, telemetry, account, license server,
private Dorsal service, or embedded API credential. Optional form filling captures
a single foreground-window screenshot after an explicit dictation when enabled.

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
LLM API is called for punctuation cleanup. The proposal is review-only, never automatically inserted.

Accessibility reads the original app, focused element, text value and selection
in memory to verify that insertion is still safe. Secure Input and secure text
fields are excluded. Normal dictation only writes AX selected text after revalidation; it
never generates Return/Send. An external application's Accessibility API cannot
provide an atomic compare-and-set transaction, so insertion is best effort and
unsupported/ambiguous fields fall back to automatic clipboard copy. Avoid editing or switching focus
while finishing a dictation.

Input Monitoring/listen-only event taps detect shortcut transitions, Escape and
interactions that invalidate a destination; Hello does not store keystrokes. It
requests Screen Recording only when you enable the optional form feature. It never
requests Camera, contacts, location or Automation access.

Hello writes no audio or transcript history to disk and logs no transcript content.
Latest text and destination snapshots are held in process memory during use and
removed on Clear/cancel/quit or when replaced by a new session. Copy and the automatic no-destination fallback place text on
the macOS clipboard; other apps and clipboard managers may retain
it. Your preferences and macOS privacy grants are managed locally. OS crash reports,
swap and Apple's own diagnostics are outside Hello's storage policy.

## Optional BYOK form filling

This mode defaults off on every launch and uses your own API account. Enabling it
permits Hello to send each form dictation's transcript, empty-field labels/bounds,
and a screenshot of the original active window to the selected provider:

- OpenAI: `https://api.openai.com/v1/responses` (`gpt-4.1-mini`).
- Anthropic: `https://api.anthropic.com/v1/messages` (`claude-sonnet-4-5`).
- OpenRouter: `https://openrouter.ai/api/v1/responses` (`openai/gpt-4.1-mini`),
  which also sends the payload to its routed model provider.

No microphone audio is sent to these services by this feature. Switching services
turns form filling off and cancels any session; enable it again to consent to the
new recipient. Hello does not fail over between these configured services. The screenshot may include
other page text, names, contact details or confidential content. Decide whether a
window is appropriate to share before using this mode. It does not capture the
whole desktop, but it is **not a redaction system**. Detected secure fields or Secure
Input block the whole capture; custom apps may not expose sensitivity correctly.

ScreenCaptureKit takes one window image after recording, and Hello verifies window
identity and Accessibility state before and after capture. The Accessibility tree
is held locally to detect changes. Existing values are not included in the field
metadata, but visible values may appear in the screenshot. Bounded inspection
refuses inaccessible or excessively large trees. Only visible, empty, enabled,
writable text fields/areas qualify for filling; detected authentication/payment
field labels are also excluded. Model replies cannot introduce arbitrary controls
or commands. Output is restricted to known field IDs and verbatim transcript spans.
Page content and model outputs are untrusted. These constraints reduce erroneous
writes but cannot prove that a model's inference of your intent is correct.

Requests use an ephemeral session with cookies/cache disabled, no redirects, and no
tools. OpenAI/OpenRouter requests set `store: false`; Anthropic uses a single-turn
Messages request with structured JSON output. OpenRouter also receives
`require_parameters: true` and `data_collection: deny` routing preferences. These
settings do **not** guarantee zero retention. Provider and routed-provider policies
still apply. See [OpenAI's data controls](https://developers.openai.com/api/docs/guides/your-data),
[Anthropic's data handling](https://platform.claude.com/docs/en/build-with-claude/structured-outputs),
and [OpenRouter's routing policies](https://openrouter.ai/docs/guides/routing/provider-selection).
Requests time out and cancellation suppresses late writes. Cancelling after upload
cannot retract information already received by the provider. Hello logs neither
screenshots, transcript payloads, response bodies nor keys. Screenshots and mapping
state stay in process memory; preview values are cleared with Clear/cancel/quit.

Each service has a separate local Keychain generic password, available only while the
Mac is unlocked, without iCloud synchronization. It is never embedded in builds or
saved to preferences. Use **Remove key** in Hello to delete it; deleting the app
alone does not remove a Keychain entry. The secure entry field clears after saving or changing provider. The saved OpenAI
key namespace is preserved across this upgrade; no re-entry is needed. The selected
provider name is a local preference. No maintainer key ships with Hello.
No API key is needed for normal dictation or local punctuation cleanup.

Form mode sets an empty field's AX value without selecting it, rather than changing
focus or synthesizing keys. Multi-field writes are not atomic. Hello stops on any
failed verification, reports verified writes and offers Copy; it does not roll back
because that could overwrite a concurrent edit. Applications can autosave or react
to a value change even though Hello never activates Submit/Send. Review the result.

Revoke access in System Settings → Privacy & Security. Delete Hello.app to uninstall.
