# Hello 0.1.1

First standalone Hello Transcriber candidate, developed from the scoped Dorsal
extraction on November 14, 2026. No earlier Hello release history is implied.

- ChatGPT desktop dictation uses the app’s standard Paste command after verifying
  the original selection and restores prior clipboard contents. Automatic
  insertion no longer has a separate switch.
- Permissions show current Allowed or Not allowed status, including screenshot
  access on the Form Filling tab.
- Successive ChatGPT dictations get spaces and conservative terminal punctuation
  at the end of the draft. Existing text is preserved.
- OpenAI transcribes and punctuates dictation after release using your API key.
  On-device Apple Speech shows live provisional words and can provide a
  completed fallback if OpenAI fails. Hello reports the reason for falling back.
- Hold Control + Option to speak and release to transcribe.
- Live transcript, persistent held-key indicator with a real microphone-level
  waveform, explicit stopped/transcribing states, Escape/Cancel, Copy and Clear.
- A small preview above the waveform shows up to three provisional words in the
  normal theme text color, updating immediately without queued playback.
- Optional local spelling memory suggests short edits to recently inserted text.
  Only user-approved pairs are remembered, with removal/clear controls and raw
  recognition available through Copy original. No cloud model training is involved.
- Normal dictation inserts only into the verified original supported text field and selection;
  changed/unsupported fields automatically copy the original transcript and show
  “Copied to clipboard.” without stealing focus. Secure fields excluded. No Return/Send.
  Empty writable fields can use a direct value write. Accepted writes are briefly
  verified without retrying; uncertain results show Check text field for review.
- Optional local punctuation suggestions are review-only. Word/name/case, number,
  sign and symbol changes are rejected; the original remains available.
- Session generations prevent quick-release and stale-callback races. Capture is
  cancelled on failure/sleep/reconfiguration and bounded to 60 seconds.
- Dashboard with local word and dictation counts, a seven-day activity chart, and
  a reset control. A single permission row guides setup one grant at a time.
  The menu bar gives quick access to the dashboard and transcript.
- Overview, Dictation, Personal Spellings and Form Filling have separate tabs.
- Sparkle offers signed updates through GitHub, with manual checks and optional
  automatic checks. Update installation requires approval.
- Actual spoken-“hello” waveform logo.
- Optional BYOK voice form filling (OpenAI, Anthropic or OpenRouter) maps a dictation to one or many empty fields
  without selecting them. Explicit cloud opt-in, window screenshot permission,
  separate personal Keychain API keys, original-window checks, exact transcript spans and
  per-value Copy for ambiguity. Existing values and detected secure fields excluded.
  Cloud inference is fallible; review forms before submitting. Partial writes stop
  and report their verified count. No Submit/Send is generated.
- Standalone universal app, scoped MIT license with Clicky/Farza attribution,
  documented provenance, Swift 6 checks and macOS CI. No private Dorsal services,
  remote usage tracking, embedded credentials or transcript history.

Requires macOS 14.2+. Optional cleanup needs macOS 26+ and an available Apple
Intelligence model. Apple Speech preview and fallback require on-device support; OpenAI processes
the final dictation audio remotely. See PRIVACY.md.

Validation recorded so far: local Xcode 27.2 universal compile on macOS 27.3;
24 cleanup-policy cases and 12 injected lifecycle/audio-callback/live-partial regression scenarios,
plus local spelling inference, replacement and storage cases. Physical
minimum-OS and Intel microphone behavior is not implied by compilation. Signed
smoke, notarization and exact-download results must accompany any published binary;
this candidate's scripts refuse publication until those gates pass.
