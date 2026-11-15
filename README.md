# Hello Transcriber

A small, standalone macOS menu bar app for push-to-talk dictation. Hold **Control +
Option**, speak, and release. Hello uses Apple Speech, then inserts into the
original supported text field or copies the transcript to your clipboard. Optional voice
form filling can map a single dictation to one or several empty fields without
selecting them first.

**Notarized release candidate:** Apple accepted version 0.1.0, build 18 on
November 14, 2026. Its ticket is stapled, its signature verifies, and Gatekeeper
accepts it as Notarized Developer ID. Local checks and macOS CI passed. A public
release still requires the remaining signed-device functionality tests and
verification of the exact downloaded artifact. See [validation](VALIDATION.md).

## Install

Use only a signed, notarized ZIP from this repository's
[Releases](https://github.com/markadebartolo/hello-transcriber/releases).
If there is no published release, there is no validated downloadable build yet.

1. Download the ZIP and `SHA256SUMS`; run `shasum -a 256 -c SHA256SUMS` beside them.
2. Extract it in Finder. Drag `Hello.app` into Applications and open it in Finder.
3. Hello opens the Dashboard. Follow the next action in **Permissions**, then
   return to Hello after approving it in macOS. Microphone and Speech Recognition
   enable dictation, Accessibility enables insertion, and Input Monitoring is
   needed when the global shortcut cannot start without it.
4. Click a supported text field, hold Control + Option while talking, then release.
   The floating recording indicator does not activate another application.

Closing the Dashboard leaves Hello in the menu bar. Choose **Open Dashboard**
from the menu bar or reopen Hello from Finder.

If a permission is denied, use Hello's settings buttons, grant access in System
Settings → Privacy & Security, then retry the shortcut. macOS may request a relaunch
for Input Monitoring. Do not disable Gatekeeper to install Hello.

## Dashboard and updates

- **Overview** shows permissions, activity and the latest transcript.
- **Dictation** controls where the transcript goes and how punctuation review works.
- **Personal Spellings** manages corrections Hello can remember.
- **Form Filling** guides provider setup, screenshot permission and opt-in.

Choose **Check for Updates** in the dashboard or menu bar. You can also turn on
automatic checks in the dashboard. Sparkle checks the signed feed on GitHub and
asks before installing an available update. The feed becomes available with the
first public release. Builds made before Sparkle was added need a one-time manual update.

## Dictation activity

The Dashboard shows words today, total words and completed dictations over the
last seven days, and a daily word chart. Counts include completed nonempty
transcriptions even when you copy them instead of inserting them. Activity starts
after updating. Only daily counts are stored locally. Use **Reset activity** to
clear them. See [privacy](PRIVACY.md).

## Behavior

- A persistent indicator shows when Control + Option are held. While listening,
  its small waveform follows microphone levels, including quiet pauses. Live
  recognition shows at most the latest three words in a 192 × 24-point preview
  above it, using the normal light/dark theme text color.
  Words update immediately with Apple's partial results, without queued playback;
  provisional speech callbacks run separately from UI rendering. Apple still
  determines how soon words arrive; recognition can revise or skip earlier words. The full
  transcript is in Hello. These partial results are provisional, not a guarantee
  of accuracy or an approval step before insertion. Release shows
  **Transcribing…** until finalization ends. If capture stops early, the indicator
  says **Microphone stopped** and stays visible until you release the keys.
- In normal dictation mode, only non-secure text fields with a writable selection and verifiable value
  through Accessibility can receive text. Changing application, typing, clicking,
  moving the selection, or editing the field invalidates insertion. Hello copies the original transcript automatically
  when the field cannot be verified and shows **Copied to clipboard.** Browser editors and custom controls may not
  support AX selected-text replacement.
  Click inside the destination before holding the shortcut; simply opening a
  document may not give its text field keyboard focus. After a fallback, Hello's
  window explains whether focus, selection, field support or write verification
  prevented insertion. Optional Form filling is separate and defaults off.
  Explicitly disabled controls and failed accessibility requests are rejected;
  native text views that omit the optional enabled flag can qualify when selected
  text replacement is supported.
  Verified completely empty fields use their writable value when available;
  existing text always uses selection replacement. Hello writes once and briefly
  waits for the app's accessibility value to update. If a write was accepted but
  cannot be verified, it says **Check text field** and retains the transcript in
  Hello for manual Copy, without an automatic duplicate paste or clipboard change.
- No Return, Send or keyboard paste is generated. If insertion is unavailable,
  Hello replaces the clipboard with the original transcript and shows a brief
  nonactivating **Copied to clipboard.** indicator. Cancel/Clear do not change it.
- **Escape** or **Cancel** discards a recording/result in progress. Capture also
  stops on sleep, audio reconfiguration, permission loss, quit, or a 60-second limit.
- The latest transcript stays in memory. **Copy** and automatic fallback change your clipboard; **Clear**
  and quitting remove Hello's transcript. Clearing Hello does not clear a clipboard
  Hello copied to. Hello keeps no transcript history.
- Optional **Preview punctuation cleanup** uses Apple's on-device Foundation Models
  when available. It disables automatic insertion. Hello copies the original transcript; review
  the punctuation suggestion before choosing **Copy**.
  Names/case, words, numbers, signs and protected symbols must match, or Hello keeps
  the original. Punctuation can still change meaning. **Copy original** is available
  when a suggestion differs. A timeout keeps the original available.
- Apple Speech requests on-device recognition when the recognizer supports it;
  otherwise Apple may process audio remotely. This is not an offline-only app.
  See [privacy](PRIVACY.md) for scope and limitations.

## Personal spellings (optional)

Open **Personal spellings → Use spelling memory**. After Hello automatically
inserts text, correct a spelling in that same field within 10 seconds. Pause for
about two seconds, then open Hello and choose **Remember spelling** or **Ignore**.
Only short word/phrase edits with unchanged surrounding text become suggestions;
changing numbers, deleting text, switching focus/apps, or editing surrounding
content can prevent a suggestion. Manually pasting from the clipboard and form
filling are not watched. Suggestions remain in memory until dismissed/replaced,
Clear/cancel, or quit. They are never learned without approval.

Approved whole-word/phrase replacements match without regard to case and use the
exact spelling you saved. They apply to future normal dictation and its automatic
clipboard fallback, before optional punctuation cleanup. **Copy original** always
provides Apple's raw recognition. Live captions show that raw recognition, so
saved-spelling changes appear in the completed transcript. This is a local
replacement dictionary, not training an AI model. No API key is required.

You can remove individual entries, **Clear saved spellings**, or disable spelling
memory to stop both observation and replacement. At most 100 approved pairs are
saved locally; no correction history or full field contents are persisted. See
[privacy](PRIVACY.md) for the storage location and observation boundaries.

## Form filling (optional)

Open Hello → **Form filling**. Choose **OpenAI**, **Anthropic**, or
**OpenRouter**, enter that service's API key in the secure field, and choose
**Save key**. Each provider has its own local Keychain entry. The key is sent only
to the selected service's fixed HTTPS API endpoint; Hello never tries it against
another provider. Choose **Allow form filling screenshots**. macOS calls this
permission **Screen Recording**; Hello uses it to capture the active window so the
model can identify text boxes. Hello does not continuously record the screen or
save screenshots. Then turn on **Send window to [provider]
and fill empty fields**. Switching providers turns this opt-in off again. This switch defaults off each launch.
Normal dictation and local cleanup do not require an API key or screen access.
With Form filling off, ordinary dictation does not query screen permission or
read an API key. Changing the form provider or removing a key while idle preserves
the existing normal transcript.

Open a form, leave its fields empty, and hold Control + Option. For example:
“First name Maya, last name Chen, city Boston.” Release to map the answers. A single
obvious empty message box can receive an entire utterance without being selected.
When the model reports an unambiguous mapping with no unmapped content, Hello checks
that values are verbatim transcript spans and that the original window and controls
have not changed, then writes only to verified empty Accessibility text controls.
It never presses Enter, Send or Submit. Websites may autosave when a value changes.

Ambiguous mappings copy the original transcript automatically and show per-field
suggestions with **Copy value**. Existing values
are never replaced by form mode. Field labels in speech are routing cues; value
spans preserve spelling, numbers and punctuation as Apple Speech transcribed them.
This mode does not apply punctuation cleanup. It cannot recover a transcription
mistake or guarantee a model's interpretation of intent; always review filled forms.

Each user brings their own key. The maintainer's key is never in the source or app.
Normal transcription and local cleanup do not require any external provider key.
The selected service receives the active-window screenshot, field labels/bounds,
and transcript:

| Provider | API and default model |
| --- | --- |
| OpenAI | Responses API · `gpt-4.1-mini` |
| Anthropic | Messages API · `claude-sonnet-4-5` |
| OpenRouter | Responses API · `openai/gpt-4.1-mini` |

Use an ordinary inference key, never an administration key. For OpenAI, use a
restricted key with **Responses → Write** and other categories **None**. API usage
requires that provider's account, model access, and available usage/billing.
OpenRouter forwards requests to a routed model provider; Hello requires schema
support and requests `data_collection: deny`. This is not a zero-retention promise.
There is no automatic fallback to a different configured service. The screenshot can contain private
page content beyond the intended fields. No screenshot is saved by Hello. Windows
with detected password controls/Secure Input are refused; this is not a general
screenshot redaction system. See [privacy](PRIVACY.md).

Only visible, empty, writable text fields/areas supported by the app's Accessibility
API are eligible. Dropdowns, checkboxes, canvas-only controls, offscreen fields,
protected controls, and forms that cannot be fully inspected fall back to automatic clipboard copy.
Typing, clicking, switching apps, scrolling/changing the page, cancellation and
timeouts invalidate the destination. Some dynamic pages change too often for a
stable snapshot. Multi-field writes are not atomic: if an app rejects a write or
changes midway, Hello stops and reports how many writes it verified. Inspect all
fields before retrying; Hello never attempts an automatic rollback.

## Requirements and build

macOS **14.2+**, Intel or Apple silicon. Optional cleanup needs macOS **26+**,
supported Apple Intelligence hardware/region/language, and an available downloaded
model. Availability is checked at runtime. The minimum OS is a deployment target,
not a claim of microphone testing on every OS/hardware combination.

Use Xcode **16+** with Swift 6 for the app and tests. Use Xcode 26+ to compile in
Foundation Models support; older SDKs omit cleanup. No package downloads, Dorsal
checkout, or private services are required. An API key is needed only for optional
AI form filling, not to build or run normal dictation.

```sh
git clone https://github.com/markadebartolo/hello-transcriber.git
cd hello-transcriber
bash hello/scripts/check.sh
```

The check compiles both architectures without signing/launching the app, verifies
six module checksums, and runs cleanup/lifecycle/form and release-gate regressions. Open
`hello/Hello.xcodeproj`, choose the Hello scheme and your own signing team for local
development. Do not launch an unsigned CI product. macOS CI deliberately uploads
no application artifacts. See [contributing](CONTRIBUTING.md) and
[release procedure](hello/RELEASING.md).

## The mark

The waveform is measured from “hello” spoken by the local macOS Samantha voice.
Its 25 bars represent normalized audio energy over the word; small icons use grouped
bins for legibility. The sample metadata and reproducible native renderer are in
`hello/brand/`. No voice recording ships in the application.

## Source and license

Hello uses real dictation modules extracted from Mark DeBartolo's Dorsal baseline
`a45b513fa0ae492980d6dfe177374f0d360baaa1`, with necessary documented integration
fixes. Five modules were originally unchanged and the factory was narrowly adapted;
[provenance](SOURCE_PROVENANCE.json) and [modifications](MODIFICATIONS.md) retain the
history. The Hello UI and packaging are new work.

Mark-owned code in this scoped repository is MIT-licensed. Clicky/Farza's MIT notice
is retained in [NOTICES.md](NOTICES.md). This release does not relicense or expose the
rest of Dorsal. No internal handoff documents or private assets are included.
