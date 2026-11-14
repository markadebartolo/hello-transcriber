# Observed validation

November 14, 2026 — macOS 27.3 (26C5035r), Xcode 27.2 (27B52), Apple silicon host.

- Handoff SHA256SUMS: all files passed before modification.
- Six upstream GitHub blobs: SHA-256 matched SOURCE_PROVENANCE.json, read-only.
- Initial unmodified draft: Xcode compile succeeded; original 12 policy cases passed.
- Updated source: Swift 6 complete concurrency checking; universal arm64/x86_64
  compile succeeded with app Swift warnings treated as errors.
- 24 cleanup-policy tests passed, including name/case changes, contractions,
  Unicode, numeric punctuation, signed amounts, currencies, symbols and omissions.
- 9 lifecycle scenarios passed against the real dictation manager with injected
  provider/audio: startup release/new session, stale partial/final/error callbacks,
  duplicate final, cancelled fallback, cancel then late final, silence, timeout
  partial, engine failure, pre-cancelled entry and stale permission completion
  (related assertions are grouped into nine scenarios).
- The compile check does not launch the app or access the microphone. Xcode emitted
  host CoreSimulator service/version diagnostics; this native macOS build succeeded.

Signed microphone/TCC/AX smoke, Apple notarization, Gatekeeper and downloaded-artifact
validation remain pending until recorded alongside a signed candidate. No unsigned
application is a release artifact. Missing evidence must never be converted to a pass.
