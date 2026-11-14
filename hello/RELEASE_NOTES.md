# Hello 0.1.0

First standalone Hello Transcriber candidate, developed from the scoped Dorsal
extraction on November 14, 2026. No earlier Hello release history is implied.

- Hold Control + Option to dictate using Apple Speech; release to finish.
- Live transcript, persistent held-key indicator with a real microphone-level
  waveform, explicit stopped/transcribing states, Escape/Cancel, Copy and Clear.
- A small single-word preview above the waveform updates immediately with provisional
  recognition; a fixed red focus letter and black remaining letters aid tracking.
- Optional local spelling memory suggests short edits to recently inserted text.
  Only user-approved pairs are remembered, with removal/clear controls and raw
  recognition available through Copy original. No cloud model training is involved.
- Normal dictation inserts only into the verified original supported text field and selection;
  changed/unsupported fields automatically copy the original transcript and show
  “Copied to clipboard.” without stealing focus. Secure fields excluded. No Return/Send.
- Optional local punctuation suggestions are review-only. Word/name/case, number,
  sign and symbol changes are rejected; the original remains available.
- Session generations prevent quick-release and stale-callback races. Capture is
  cancelled on failure/sleep/reconfiguration and bounded to 60 seconds.
- Visible setup window at launch and Finder reopen; actual spoken-“hello” waveform logo.
- Optional BYOK voice form filling (OpenAI, Anthropic or OpenRouter) maps a dictation to one or many empty fields
  without selecting them. Explicit cloud opt-in, window screenshot permission,
  separate personal Keychain API keys, original-window checks, exact transcript spans and
  per-value Copy for ambiguity. Existing values and detected secure fields excluded.
  Cloud inference is fallible; review forms before submitting. Partial writes stop
  and report their verified count. No Submit/Send is generated.
- Standalone universal app, scoped MIT license with Clicky/Farza attribution,
  documented provenance, Swift 6 checks and macOS CI. No private Dorsal services,
  analytics, embedded credentials or transcript history.

Requires macOS 14.2+. Optional cleanup needs macOS 26+ and an available Apple
Intelligence model. Apple Speech requests on-device processing where supported;
otherwise Apple may process audio remotely. See PRIVACY.md.

Validation recorded so far: local Xcode 27.2 universal compile on macOS 27.3;
24 cleanup-policy cases and 12 injected lifecycle/audio-callback/live-partial regression scenarios,
plus local spelling inference, replacement and storage cases. Physical
minimum-OS and Intel microphone behavior is not implied by compilation. Signed
smoke, notarization and exact-download results must accompany any published binary;
this candidate's scripts refuse publication until those gates pass.
