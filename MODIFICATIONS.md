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
