# Hello Transcriber

A small, standalone macOS menu bar app for push-to-talk dictation. Hold **Control +
Option**, speak, and release. Hello uses Apple Speech, then inserts into the
original supported text field or copies the transcript to your clipboard. Optional voice
form filling can map a single dictation to one or several empty fields without
selecting them first.

**Release candidate:** source builds and regression tests have run locally. A public
binary release is gated on signed-device smoke tests, Apple notarization, and
verification of the downloaded artifact. See [validation](VALIDATION.md).

## Install

Use only a signed, notarized ZIP from this repository's
[Releases](https://github.com/markadebartolo/hello-transcriber/releases).
If there is no published release, there is no validated downloadable build yet.

1. Download the ZIP and `SHA256SUMS`; run `shasum -a 256 -c SHA256SUMS` beside them.
2. Extract it in Finder. Drag `Hello.app` into Applications and open it in Finder.
3. Hello opens a visible setup window. Choose **Enable audio** and allow Microphone
   and Speech Recognition. Enable Accessibility for insertion; Input Monitoring
   may also be needed for the global shortcut.
4. Click a supported text field, hold Control + Option while talking, then release.
   The floating recording indicator does not activate another application.

Closing the window leaves Hello in the menu bar. Reopen Hello from Finder to bring
the window back if the icon is hidden or hard to find.

If a permission is denied, use Hello's settings buttons, grant access in System
Settings → Privacy & Security, then retry the shortcut. macOS may request a relaunch
for Input Monitoring. Do not disable Gatekeeper to install Hello.

## Behavior

- In normal dictation mode, only enabled, non-secure text fields exposing a verifiable selection and value
  through Accessibility can receive text. Changing application, typing, clicking,
  moving the selection, or editing the field invalidates insertion. Hello copies the original transcript automatically
  when the field cannot be verified and shows **Copied to clipboard.** Browser editors and custom controls may not
  support AX selected-text replacement.
- No Return, Send or keyboard paste is generated. If insertion is unavailable,
  Hello replaces the clipboard with the original transcript and shows a brief
  nonactivating **Copied to clipboard.** indicator. Cancel/Clear do not change it.
- **Escape** or **Cancel** discards a recording/result in progress. Capture also
  stops on sleep, audio reconfiguration, permission loss, quit, or a 60-second limit.
- The latest transcript stays in memory. **Copy** and automatic fallback change your clipboard; **Clear**
  and quitting remove Hello's transcript. Clearing Hello does not clear a clipboard
  Hello copied to. There is no transcript history or analytics.
- Optional **Preview punctuation cleanup** uses Apple's on-device Foundation Models
  when available. It disables automatic insertion. Hello copies the original transcript; review
  the punctuation suggestion before choosing **Copy**.
  Names/case, words, numbers, signs and protected symbols must match, or Hello keeps
  the original. Punctuation can still change meaning. **Copy original** is available
  when a suggestion differs. A timeout keeps the original available.
- Apple Speech requests on-device recognition when the recognizer supports it;
  otherwise Apple may process audio remotely. This is not an offline-only app.
  See [privacy](PRIVACY.md) for scope and limitations.

## Voice form filling (optional)

Open Hello → **Voice form filling**. Choose **OpenAI**, **Anthropic**, or
**OpenRouter**, enter that service's API key in the secure field, and choose
**Save key**. Each provider has its own local Keychain entry. The key is sent only
to the selected service's fixed HTTPS API endpoint; Hello never tries it against
another provider. Enable Screen Recording, then turn on **Send window to [provider]
and fill empty fields**. Switching providers turns this opt-in off again. This switch defaults off each launch.
Normal dictation and local cleanup do not require an API key or screen access.

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
