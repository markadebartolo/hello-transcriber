# Observed validation

November 14, 2026 — macOS 27.3 (26C5035r), Xcode 27.2 (27B52), Apple silicon host.

## Notarized candidate 0.1.2, build 29

- Source commit `e452d3a298596fc594307aaff0ce057522495a0d`. Apple submission
  `9c790047-f396-4c1e-9c7a-19d9bd81f8e8` was **Accepted**.
- The universal local build and [macOS 15 and 26 CI](https://github.com/markadebartolo/hello-transcriber/actions/runs/43670198263)
  passed. The byte-identical GitHub draft download passed signature, staple,
  Gatekeeper and Sparkle checks and launched.
- With microphone access revoked, the signed app showed **Not allowed**.
  **Set up microphone** opened Privacy & Security → Microphone from another
  pane. After the original grant was restored, Hello showed **Allowed**.
- Live dictation, focus change, and cancellation on the exact build 29 download
  remain pending. Build 28's physical results are recorded separately below.

## Notarized candidate 0.1.1, build 28

- Source commit `1aa5e4bbb8f8127e61def9231aa79637dc39e698`.
- Apple submission `7b70cc8c-9d7a-4e67-9283-a2fa0bb28ced` was **Accepted**.
  The installed app and the app extracted locally from the candidate ZIP passed
  signature, staple, and Gatekeeper checks. Both Sparkle signatures verified.
- The local universal Swift 6 build and regression suite passed.
  [Hosted CI](https://github.com/markadebartolo/hello-transcriber/actions/runs/43666076885)
  passed on macOS 15 and 26 after the repository became public.
- Hello detected the saved OpenAI key on launch. The maintainer tested live
  dictation and reported that punctuation and formatting appeared fixed and
  that the final result took longer than Apple Speech.
- The ZIP downloaded from the GitHub draft matched the signed candidate byte
  for byte. The extracted app passed signature, staple, and Gatekeeper checks
  and opened successfully. The maintainer confirmed the exact download replaced
  only the selected text in TextEdit, cancelled with Escape without inserting,
  and copied the transcript when focus moved to another TextEdit window.
- The maintainer also confirmed that Safari accepted dictation in a disposable
  text area and left the focused password field empty.
- The microphone permission recovery link incorrectly opened iCloud on this
  Mac. Build 29 replaces this candidate.

## Notarized candidate 0.1.0, build 18

- Source: [6f564c21ad6fc6a05f565bc2fbe31ae4d627dd8e](https://github.com/markadebartolo/hello-transcriber/commit/6f564c21ad6fc6a05f565bc2fbe31ae4d627dd8e).
  Later documentation updates do not change that binary's source revision.
- Apple submission `65f2d2a4-65cd-4b1c-9aa0-90a75aa673b3`: **Accepted**, no issues
  reported. Submitted November 14, 2026 in America/New_York
  (Apple upload timestamp: November 15, 2026, 00:32:50 UTC).
- Developer ID Application: Mark DeBartolo (`QA3AY5HLGM`), bundle
  `com.markdebartolo.hello`, hardened runtime, secure timestamp and microphone-only
  entitlement verified. Both architecture CDHashes match the candidate manifest.
- Stapling and ticket validation succeeded for the candidate and installed app.
  Strict code signature verification passed; Gatekeeper reported **accepted**,
  `source=Notarized Developer ID`.
- Packaged `Hello-0.1.0-b18.zip`, extracted it locally, and repeated ticket,
  signature, architecture-hash and Gatekeeper checks successfully. SHA-256:
  `91976d082c235109248640bb65b06e1366d32951495bed72f13bec972fe7bd8b`.
  This was a local extraction check, not a downloaded-release functionality test.
- Full local compile/regressions and [macOS 15/26 CI](https://github.com/markadebartolo/hello-transcriber/actions/runs/43626215532)
  passed, including 12 lifecycle/audio/partial scenarios, 24 cleanup cases,
  insertion readback/cancellation, empty/existing field handling, three-word
  captions, basic/form prerequisite isolation, spelling storage and provider fixtures.

At the user's request, this candidate was submitted for notarization while the
remaining functionality tests were still pending. Notarization is not evidence
that dictation, field insertion, permission recovery or form filling work correctly.
Build 18 was a validation candidate.

## Earlier engineering checks

- Handoff SHA256SUMS: all files passed before modification.
- Six upstream GitHub blobs: SHA-256 matched SOURCE_PROVENANCE.json, read-only.
- Initial unmodified draft: Xcode compile succeeded; original 12 policy cases passed.
- Updated source: Swift 6 complete concurrency checking; universal arm64/x86_64
  compile succeeded with app Swift warnings treated as errors.
- 24 cleanup-policy tests passed, including name/case changes, contractions,
  Unicode, numeric punctuation, signed amounts, currencies, symbols and omissions.
- 10 lifecycle scenarios passed against the real dictation manager with injected
  provider/audio: startup release/new session, stale partial/final/error callbacks,
  duplicate final, cancelled fallback, cancel then late final, silence, timeout
  partial, engine failure, pre-cancelled entry and stale permission completion
  plus the actual permission bridge with background granted/denied callbacks and
  synchronous completion (related assertions are grouped into ten scenarios).
- Form-policy/planner/write-sequencing regressions passed with fixtures: exact
  Unicode names and amounts; no partial tokens, invented or duplicate IDs;
  ambiguity/unmapped-content blocks automatic fill; stale/failed writes stop;
  store=false/no tools; refused, malformed, incomplete and duplicate outputs fail.
  These fixtures did not make an API call, capture a screen or fill a live form.
- A timestamped Developer ID signed build with the visible launch window opened
  successfully through native app control on this Mac. Its setup controls were
  observable. This does not imply microphone or form behavior was validated.
- The compile check does not launch the app or access the microphone. Xcode emitted
  host CoreSimulator service/version diagnostics; this native macOS build succeeded.

The remaining signed microphone/TCC/AX smoke and downloaded-artifact functionality
validation are pending. Notarization and Gatekeeper results for build 18 are above. No unsigned
application is a release artifact. Missing evidence must never be converted to a pass.

Signed build 7 revealed an actual TCC callback isolation crash on this Mac. The
callback bridge was corrected and a regression added; signed permission recovery
must be re-observed on the replacement candidate before the release gate can pass.
