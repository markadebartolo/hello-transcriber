# Hello 0.1.0

**Draft release notes — intended behavior only. This code has not yet been compiled or validated on macOS, notarized, or released. Replace this notice only after the checks in SMOKE_TEST.md pass.**

Hold Control + Option, speak, and release to turn your voice into text.

- A small macOS menu bar app using the real Dorsal dictation engine.
- Apple Speech transcription, with on-device recognition when supported.
- Optional on-device punctuation cleanup that preserves the original words and numbers.
- Inserts into the original supported text field; offers Copy when the field changes or the app does not support direct insertion.
- Password fields are excluded. No Return/Send action is generated.
- No Dorsal screenshot, cursor, analytics, licensing, or Worker services are included.

Requires macOS 14.2 or later. Optional cleanup requires supported Apple Intelligence hardware with macOS 26 or later. Apple Speech may use Apple's servers when on-device recognition is unavailable.

This is a first release. Test your target apps before relying on automatic insertion. The latest transcript stays in memory until cleared or quit; no transcript history is written to disk.
