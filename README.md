# Hello Transcriber

A small, standalone macOS menu bar app for push-to-talk dictation. Hold **Control +
Option**, speak, and release. Hello uses Apple Speech, then inserts into the
original supported text field or leaves a transcript ready to copy.

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

- Only enabled, non-secure text fields exposing a verifiable selection and value
  through Accessibility can receive text. Changing application, typing, clicking,
  moving the selection, or editing the field invalidates insertion. Use **Copy**
  when the field cannot be verified. Browser editors and custom controls may not
  support AX selected-text replacement.
- No Return, Send, keyboard paste, or automatic clipboard replacement is generated.
- **Escape** or **Cancel** discards a recording/result in progress. Capture also
  stops on sleep, audio reconfiguration, permission loss, quit, or a 60-second limit.
- The latest transcript stays in memory. **Copy** changes your clipboard; **Clear**
  and quitting remove Hello's transcript. Clearing Hello does not clear a clipboard
  you explicitly copied to. There is no transcript history or analytics.
- Optional **Preview punctuation cleanup** uses Apple's on-device Foundation Models
  when available. It disables automatic insertion and requires review before Copy.
  Names/case, words, numbers, signs and protected symbols must match, or Hello keeps
  the original. Punctuation can still change meaning. **Copy original** is available
  when a suggestion differs. A timeout keeps the original available.
- Apple Speech requests on-device recognition when the recognizer supports it;
  otherwise Apple may process audio remotely. This is not an offline-only app.
  See [privacy](PRIVACY.md) for scope and limitations.

## Requirements and build

macOS **14.2+**, Intel or Apple silicon. Optional cleanup needs macOS **26+**,
supported Apple Intelligence hardware/region/language, and an available downloaded
model. Availability is checked at runtime. The minimum OS is a deployment target,
not a claim of microphone testing on every OS/hardware combination.

Use Xcode **16+** with Swift 6 for the app and tests. Use Xcode 26+ to compile in
Foundation Models support; older SDKs omit cleanup. No package downloads, API keys,
Dorsal checkout, or private services are required.

```sh
git clone https://github.com/markadebartolo/hello-transcriber.git
cd hello-transcriber
bash hello/scripts/check.sh
```

The check compiles both architectures without signing/launching the app, verifies
six module checksums, and runs cleanup/lifecycle regressions. Open
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
