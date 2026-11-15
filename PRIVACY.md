# Privacy

Hello captures microphone audio during push-to-talk sessions. It uses your own
provider keys from macOS Keychain. Hello has no telemetry, sign-in, or transcript history.

| Feature | Data sent off this Mac |
| --- | --- |
| Dictation | The completed microphone recording goes to OpenAI after release. The destination draft stays on this Mac. |
| Live captions and local fallback | Apple Speech runs on-device when supported. |
| Optional Form Filling | The transcript, eligible field labels and positions, and one screenshot of the active window go to the selected provider. OpenAI still handles the separate audio transcription request. |
| Activity and personal spellings | Counts and approved spelling pairs stay on this Mac. |
| Software updates | Sparkle requests the signed release feed from GitHub. |

If Speech Recognition is allowed and a compatible local recognizer exists,
Hello uses Apple's Speech framework for provisional words and a possible local
fallback. It requires on-device recognition for that path. If no local
recognizer is available, the waveform can still show while you record. Apple
Speech authorization is optional and never enables remote Apple processing.

With an OpenAI key saved in Keychain, releasing the dictation shortcut sends the
completed recording from memory to the OpenAI audio transcription endpoint over
HTTPS. This uses your key and can incur charges. Only the microphone recording is
sent for transcription. The destination draft and screenshots are excluded.
Cancel before release to discard the recording without submitting it. After
release, cancelling stops local processing but cannot recall data already sent.
If OpenAI fails, Hello can use a completed on-device Apple result. It reports
the failure and does not submit the same audio to another server. See
[OpenAI’s API data controls](https://developers.openai.com/api/docs/guides/your-data).

Optional punctuation cleanup runs through the on-device
[Foundation Models framework](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).
Hello sends it only the transcript, not text from the destination field. No external
LLM API is called for the separate punctuation review. The proposal is review-only, never automatically inserted.

Accessibility reads the original app, focused element, text value and selection
in memory to verify that insertion is still safe. Secure Input and secure text
fields are excluded. Normal dictation writes AX selected text after revalidation,
or sets AXValue for a verified completely empty field with a writable value.
For ChatGPT, Hello temporarily puts the transcript on the system clipboard and
invokes the app’s Paste command once. It keeps a bounded snapshot of readable
clipboard items in memory, restores it if the clipboard still belongs to Hello,
and leaves a newer user copy alone. Clipboard managers may observe the temporary
transcript. Hello
never generates Return/Send. An external application's Accessibility API cannot
provide an atomic compare-and-set transaction, so insertion is best effort and
unsupported/ambiguous fields fall back to automatic clipboard copy. Avoid editing or switching focus
while finishing a dictation.
After an accepted write, Hello briefly polls the original focused field's value
without writing again. An unverified result shows **Check text field** and keeps
the transcript available for manual Copy; it does not automatically replace the
clipboard. Cancel or a context change stops verification.

Input Monitoring/listen-only event taps detect shortcut transitions, Escape and
interactions that invalidate a destination. Hello does not store keystrokes.
Use **Allow form filling screenshots** to request Screen Recording for Form Filling.
Hello never requests Camera, contacts, location or Automation access.

The Dashboard counts words and completed nonempty dictations by local calendar
day. Only numeric totals and their dates are saved to this Mac's Hello preferences.
The dashboard shows the last seven days and removes older entries when recording
new activity. **Reset activity** clears the saved totals. The activity feature
does not keep transcript text or send usage data off this Mac.

Hello writes no audio or full transcript history to disk and logs no transcript content.
Latest text and destination snapshots are held in process memory during use and
removed on Clear/cancel/quit or when replaced by a new session. Copy and the automatic no-destination fallback place text on
the macOS clipboard; other apps and clipboard managers may retain
it. Your preferences and macOS privacy grants are managed locally. OS crash reports,
swap and Apple's own diagnostics are outside Hello's storage policy.

## Optional personal spellings

Spelling memory defaults off. When enabled, after a verified normal insertion
Hello reads that same focused, non-secure field for at most 10 seconds, checking
every half-second. It compares only the inserted segment while requiring unchanged
surrounding text and the same application/element. Losing focus, switching apps,
Secure Input, Clear/cancel, a new dictation or disabling the feature stops the watch.
No keystroke content is recorded, and no correction text goes to a cloud API.
Form filling and manual clipboard pastes do not create a watch.

Stable short edits become in-memory suggestions. Only **Remember spelling** saves
a pair of recognized/replacement words (up to three words and 80 UTF-16 units on
each side, at most 100 pairs). Approved spellings can contain personal names;
they are stored in plain text at `~/Library/Application Support/Hello/spellings.json`
with owner-only file permissions. Hello does not synchronize this file, though
your own backups may include it. Full transcripts, original field values and
rejected suggestions are not written to this dictionary. **Remove** deletes a
pair; **Clear saved spellings** deletes the file. Deleting Hello.app alone does
not delete it. Disabling memory preserves existing entries but stops their use.

Saved spellings are applied locally to normal dictation before insertion or
automatic clipboard fallback; **Copy original** retains raw recognition. They do
not train Apple or an external model. Live captions above the waveform show
provisional raw recognition, which can change as speech processing catches up.

## Optional BYOK form filling

This mode defaults off on every launch and uses your own API account. Enabling it
permits Hello to send each form dictation's transcript, empty-field labels/bounds,
and a screenshot of the original active window to the selected provider:

- OpenAI: `https://api.openai.com/v1/responses` (`gpt-4.1-mini`).
- Anthropic: `https://api.anthropic.com/v1/messages` (`claude-sonnet-4-5`).
- OpenRouter: `https://openrouter.ai/api/v1/responses` (`openai/gpt-4.1-mini`),
  which also sends the payload to its routed model provider.

The form request uses the completed transcript. Switching services turns form
filling off and cancels any session. Enable it again to consent to the new
recipient. Hello does not fail over between these configured services. The screenshot may include
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
alone does not remove a Keychain entry. The secure entry field clears after saving
or changing provider. Dictation and OpenAI Form Filling share the same saved
OpenAI key. The selected form provider is a local preference. Local punctuation
review uses the on-device Foundation Models framework without a key.

Form mode sets an empty field's AX value without selecting it, rather than changing
focus or synthesizing keys. Multi-field writes are not atomic. Hello stops on any
failed verification, reports verified writes and offers Copy; it does not roll back
because that could overwrite a concurrent edit. Applications can autosave or react
to a value change even though Hello never activates Submit/Send. Review the result.

Revoke access in System Settings → Privacy & Security. Delete Hello.app to uninstall.


## Software updates

Sparkle contacts the Hello GitHub release feed when you check for updates or opt
into automatic checks. GitHub receives ordinary HTTPS request information such as
your IP address. Hello disables Sparkle system profiling. The update check sends
no transcripts, screenshots, API keys or dictation activity. Updates require a
signed feed and signed archive and are installed only after approval.
