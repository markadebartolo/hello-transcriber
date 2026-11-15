# Extraction and changes

Baseline: `markadebartolo/dorsal-beta` at `a45b513fa0ae492980d6dfe177374f0d360baaa1`.
All six upstream blobs were retrieved read-only and verified against the handoff
SHA-256 values on November 14, 2026. The original checkout and repository were not
modified. `SOURCE_PROVENANCE.json` preserves original/draft checksums;
`SOURCE_CHECKSUMS.json` records the current reviewed extraction. Update the latter
only alongside a documented change. The initial local import commit preserves the
five original modules and narrow factory adaptation for comparison.

- **BuddyDictationManager.swift:** keep the original shortcut, AVAudioEngine,
  permission and finalization pipeline. Claim a generation before awaits; gate
  every callback and fallback against it; cancel superseded provider sessions;
  prevent quick-release/permission completions from resetting newer sessions.
  Prepare Apple Speech before capture, removing the private-provider handshake
  buffer queue (which retained borrowed audio buffers and read actor state on the
  audio thread). The tap now consumes buffers synchronously and sends only a
  numeric audio level to the main actor. Add injectable capture/provider boundaries
  for regression tests, validate microphone format, remove taps only when installed,
  stop all capture on errors, bound recording to 60 seconds, and require both
  permissions in the short permission-cache window. Remove obsolete keyterm bias.
- **BuddyTranscriptionProvider.swift:** replace conditional private-service factory
  branches with the Apple Speech factory; mark the provider main-actor isolated and
  audio sessions/callbacks Sendable. No private client/service implementation ships.
- **AppleSpeechTranscriptionProvider.swift:** serialize request/task/state across
  audio, Speech and main threads; ignore cancelled/duplicate callbacks; reject an
  unavailable recognizer. No transcript is logged. On-device requirement remains
  conditional on Apple's reported support; no hidden remote retry when required.
- **GlobalPushToTalkShortcutMonitor.swift:** invalidate destinations on keyboard or
  mouse interaction, cancel on Escape and tap disruption. Its listen-only callback
  is installed on the main run loop; no keys are suppressed or generated.
- **OnDeviceModel.swift and DorsalLog.swift:** unchanged, preserving original hashes.
  Their historical internal names/comments are attribution, not product branding.

The Hello UI, target-field insertion, cleanup policy, icon, documentation, tests,
and release tooling are new integration work. They were an unvalidated draft:
this repository does not imply that standalone Hello existed in Dorsal.

Integration changes require a typed selection range, enabled non-secure text role,
original field value, original process, and current focus before AX selected-text
replacement. User interaction/app switching invalidates the destination. Accessibility calls are bounded and the frontmost app is checked again before writing. No
clipboard mutation happens until Copy; there is no keyboard paste or Return/Send.
Cleanup is optional, local and review-only; word identity alone cannot guarantee
meaning. Strict token/number/symbol checks preserve the original on rejection.

Swift 6 complete concurrency checking is enabled. The project has no default
signing team, packages, sibling source tree, secrets, analytics or private service.
Release tooling derives the team from a verified identity, requires observed smoke
evidence before notarization/publication, checks hardened runtime/entitlements,
verifies tag-to-source identity, and rechecks the downloaded signed artifact.

## November 14, 2026 — visible window and optional form filling

Added a launch/reopen window because a menu-only app was not discoverable on the
validation Mac. Added new Hello-only form modules for Keychain storage, bounded
Accessibility snapshots, single-window ScreenCaptureKit images, OpenAI structured
field mapping and conservative verified writes. Normal insertion remains selection
based; form mode explicitly opts into empty-field AX value writes. No Dorsal module
changed for this feature. Original-module checksums/provenance remain intact.

Form regression fixtures cover invented/duplicate IDs, changed names/amounts, cut
tokens, ambiguous/unmapped output, interrupted writes, malformed/refused/incomplete
responses and request privacy flags. They are not claims of live API accuracy,
actual screen permissions or cross-application insertion. A new required `forms`
release smoke gate prevents publishing without those observed checks.

At the user's request, failed/no-destination insertion now automatically copies
the original transcript and displays a three-second nonactivating result. Cancel,
Clear and empty results never trigger that fallback. Cleanup suggestions still
require review; automatic fallback always uses the original speech transcript.

The Xcode 16/macOS 15 CI job exposed missing ScreenCaptureKit Sendable annotations
in that SDK. The import is explicitly preconcurrency; shareable-content snapshots
remain read-only in the main-actor form context. Newer SDK compilation and older
SDK CI are both required.

## November 14, 2026 — observed permission callback crash

Signed build 7 exited with EXC_BREAKPOINT / `_dispatch_assert_queue_fail` during
a TCC permission response on a background queue. Legacy Speech completion blocks
were inheriting MainActor isolation. Added a nonisolated, Sendable continuation
bridge in BuddyDictationManager and used it for both manager and Hello setup
permission requests. Main-actor state changes occur only after awaiting the result.
Added a regression that invokes the real bridge off-main with granted/denied results
and synchronously, verifying resumption on MainActor. The reviewed current manager
checksum changed; original provenance hashes remain intact. Permission dialogs
no longer display a misleading in-app Cancel button that cannot dismiss macOS TCC.

## November 14, 2026 — three-provider BYOK

Added explicit OpenAI, Anthropic and OpenRouter adapters and separate Keychain
service names, preserving the existing OpenAI entry. Provider selection is local;
changing it cancels pending work and disables cloud form filling until re-enabled.
No maintainer key, shared backend or cross-service key fallback was introduced.
Requests use each documented native vision/structured-output format, fixed HTTPS
endpoints and redirect rejection. OpenRouter requires schema support and requests
non-collecting provider routing. Common exact-span and destination checks remain.
Fixture tests cover all three request/auth formats and provider-specific incomplete,
refused and malformed responses. They do not claim live Anthropic/OpenRouter access.

## November 14, 2026 — observed first-audio-buffer crash

Signed builds 10 and 11 crashed with EXC_BREAKPOINT / `_dispatch_assert_queue_fail`
on `RealtimeMessenger.mServiceQueue`, through `AVAudioNodeTap::TapMessage` into
Hello. The AVAudioEngine tap closure was created inside MainActor-isolated
BuddyMicrophoneCapture.start, and the legacy SDK callback inherited that actor.
Moved production callback creation to an explicitly nonisolated, Sendable factory.
It still consumes each borrowed audio buffer synchronously; UI updates remain on
MainActor. A regression invokes that exact handler with a PCM buffer from a
background queue and checks delivery, then resumes MainActor. Updated only the
reviewed current module checksum; original provenance hashes are unchanged.
The audio-engine configuration notification receiver is also explicitly Sendable
before dispatching cancellation onto MainActor, since it may arrive off-main.
The earlier indicator-only change did not fix this runtime microphone crash.

## November 14, 2026 — live captions and approved local spellings

The compact recording pill now shows provisional Apple Speech words in a small
single-line caption above its waveform. Caption updates replace prior partials
and show raw recognition; approved spelling changes appear in the final transcript.
The panel remains nonactivating and retains the small pill when no caption exists.

Optional spelling memory watches only a verified normal insertion in the same
focused non-secure field for 10 seconds, per the user's requested limit. Surrounding
text must remain unchanged. Stable short word/phrase edits become local suggestions;
only explicit Remember spelling saves a pair. Whole-word/phrase replacements are
case-insensitive, one-pass, and retain the user's exact preferred spelling. Raw
recognition stays available through Copy original. Forms and manual clipboard
pastes are excluded. Disabling, cancellation, focus/app changes, new dictation and
timeout end observation. Saved pairs have owner-only file permissions, with remove
and clear controls. No external model training or network request is added.
Regression tests cover partial revisions, edit boundaries, numbers, Unicode,
noncascading replacements, persistence, removal, corrupt data and write failures.

## November 14, 2026 — waveform-only listening and insertion feedback

Removed the visible Listening word and reduced the active microphone pill to
96 × 34 points; live captions remain above it. Startup, transcribing and stopped
states retain their distinct labels, and the cancel control remains available.
A reported TextEdit fallback is not treated as a passed insertion test. Added
specific user-facing fallback reasons, Unicode-valid selection bounds, an immediate
pre-write recheck, and exact value readback before reporting insertion success.
No whole-field replacement, synthetic paste, Return or Send was introduced.

## November 14, 2026 — writable native text fields and single-word preview

Computer inspection of build 15 showed TextEdit's editable text area while Hello
reported an unsupported focused control. The old eligibility check treated a
missing AXEnabled attribute as disabled. Native views can omit that attribute;
eligibility now requires writable AXSelectedText and accepts an omitted flag only
for attributeUnsupported/noValue. Explicit false, malformed values, communication
failures, unsupported roles and secure fields still reject insertion. Original
focus, PID, full value and UTF-16 selection checks and exact write readback remain.
Thirteen capability tests cover this boundary. This is not a substitute for
repeating the failed physical TextEdit insertion test on the signed candidate.

Replaced the 260 × 30-point phrase preview with a 144 × 24-point newest-word
preview. Its red focus letter stays in a fixed column, with the other letters
black on white; the active combined HUD is 144 × 60 points. Partial revisions
appear immediately with no stale playback queue or timer. Grapheme-based coloring
preserves accents and emoji. The full provisional transcript remains in Hello;
the compact preview can skip earlier words when recognition delivers a batch.

## November 14, 2026 — direct provisional speech callbacks

The user confirmed build 16 inserted successfully, but reported delayed word
changes. The caption already has no debounce, playback timer or word animation.
Apple Speech now uses a dedicated serial user-initiated callback queue instead
of its default main queue, and forwards didHypothesizeTranscription directly to
the existing generation-checked MainActor callback. Final recognition, error and
system cancellation have explicit delegate handlers; cancellation still suppresses
late hypotheses. Punctuation, on-device preference, finalization timeout and the
final transcript policy are unchanged. No second recognizer or cloud service was
added. Updated the current provider checksum; original provenance remains intact.

Apple controls hypothesis cadence, so this removes UI-queue contention rather
than promising a fixed latency or earlier words from the recognition engine.
The speed improvement still needs physical comparison on the signed app.
API references: [recognizer callback queue](https://developer.apple.com/documentation/speech/sfspeechrecognizer/queue)
and [provisional transcription delegate](https://developer.apple.com/documentation/speech/sfspeechrecognitiontaskdelegate/speechrecognitiontask(_:didhypothesizetranscription:)).

## November 14, 2026 — empty composers, delayed verification and plain captions

A reported ChatGPT insertion failure showed an accepted AX write followed by a
readback mismatch in Hello. The destination itself was not directly inspected,
so app-specific success is still pending validation. A verified completely empty
field now uses AXValue when writable; any existing text, including whitespace,
still requires selected-text replacement. There is only one write. Readback is
polled briefly to allow asynchronously updated accessibility values, with session,
focus, secure-field and cancellation checks. Unverified accepted writes show
Check text field and retain manual Copy without replacing the clipboard or
automatically retrying. No key events, Return or Send are generated. Tests cover
empty versus existing fields, delayed/immediate readback, timeout, cancellation
and context changes. The controller remains busy until verification completes.

Restored ordinary theme-colored captions with at most three words, in a
192 × 24-point preview. Removed the red-letter and fixed-column presentation.
Basic dictation's startup gate now explicitly skips all screen/key checks when
Form filling is off, verified with failing probe closures in the regressions.
Changing the form provider or removing a key while idle no longer clears a normal
transcript. Form filling remains separately opt-in and off at launch.


## November 14, 2026 — optional OpenAI speech and draft-aware insertion

Hello can select the provider while the dictation manager is idle. The
shared manager change retains its generation, cancellation and microphone
lifecycle. Apple Speech provides an on-device preview and a fallback after an OpenAI
failure. The OpenAI provider
holds a bounded mono WAV recording in memory, requests transcription only after
release, rejects redirects and reports network or authorization failure without
sending the recording to a different server. The key stays in Keychain until a
session needs it. No destination draft or screenshot enters the transcription
request. The original source provenance stays unchanged and the current
manager and Apple preview checksums were refreshed.

ChatGPT end-of-draft insertion adds a spacing boundary and conservative terminal
punctuation to the inserted chunk only. Existing draft content, selected-text
replacement, recognized words and the separate form-filling route are preserved.
