# Hello 0.1.0

First standalone Hello Transcriber candidate, developed from the scoped Dorsal
extraction on November 14, 2026. No earlier Hello release history is implied.

- Hold Control + Option to dictate using Apple Speech; release to finish.
- Live transcript, recording indicator/audio feedback, Escape/Cancel, Copy and Clear.
- Insert only into the verified original supported text field and selection;
  changed/unsupported fields offer Copy. Secure fields excluded. No Return/Send.
- Optional local punctuation suggestions are review-only. Word/name/case, number,
  sign and symbol changes are rejected; the original remains available.
- Session generations prevent quick-release and stale-callback races. Capture is
  cancelled on failure/sleep/reconfiguration and bounded to 60 seconds.
- Standalone universal app, scoped MIT license with Clicky/Farza attribution,
  documented provenance, Swift 6 checks and macOS CI. No private Dorsal services,
  screenshots, analytics, embedded credentials or transcript history.

Requires macOS 14.2+. Optional cleanup needs macOS 26+ and an available Apple
Intelligence model. Apple Speech requests on-device processing where supported;
otherwise Apple may process audio remotely. See PRIVACY.md.

Validation recorded so far: local Xcode 27.2 universal compile on macOS 27.3;
24 cleanup-policy cases and 9 injected lifecycle regression scenarios. Physical
minimum-OS and Intel microphone behavior is not implied by compilation. Signed
smoke, notarization and exact-download results must accompany any published binary;
this candidate's scripts refuse publication until those gates pass.
