# Signed Mac release checks

Run the signed candidate from `release.sh prepare` through Finder. Never launch an
unsigned build. Record OS version, hardware, app versions, tester, date and literal
observations in signed-smoke.json; see RELEASING.md. No checkbox is pre-passed.

Required checks (the IDs are release-gate keys):

- [ ] **identity:** Hello waveform icon, bundle `com.markdebartolo.hello`, expected
  Developer ID/team and hardened runtime; visible setup window at launch, close
  leaves app running, Finder reopen restores window; no effect on existing Dorsal grants.
- [ ] **permissions:** fresh Hello identity prompts once for Microphone and Speech;
  deny/recover each through Settings. Accessibility/Input Monitoring denial is
  visible; Retry works after grants/relaunch. No Screen Recording prompt in normal mode; Camera is never requested.
- [ ] **microphone:** actual spoken test in TextEdit; recording HUD does not take
  focus; first words survive; audio meter responds; release stops microphone.
  The indicator stays visible for the entire key hold, including silent pauses;
  its waveform follows real audio. If capture stops early, it shows Microphone
  stopped rather than disappearing or claiming to listen. Release shows
  Transcribing until finalization ends. Cancel while held leaves a stopped state.
  At most the latest three recognized words appear above the small waveform and
  update immediately in the normal theme text color. Check accented words and
  long words in light/dark mode. The full
  text stays in Hello; revisions may skip earlier words in this compact preview.
  The caption does not take focus or insert partial text.
- [ ] **selection:** replace only a selected word in TextEdit; test caret insertion
  and Unicode/surrogate text. Try Safari textarea and Notes. Unsupported fields
  offer Copy. Record which app/version genuinely supports AX insertion.
  Test an empty rich-text composer as well as an existing draft. Empty writable
  fields may use AXValue; existing text must only replace the captured selection.
  Delayed readback must not duplicate insertion. An accepted but unverified write
  shows Check text field, preserves the clipboard and retains manual Copy.
- [ ] **focus:** switch field/app or selection, type/click during capture and
  cleanup, including switching away and back. No stale or wrong-field insertion.
- [ ] **secure_field:** password field and Secure Input never receive automatic
  insertion. Use disposable test text, never a real password.
- [ ] **cancellation:** quick tap/release, repeated holds, Escape/Cancel during
  startup, recording, finalization and cleanup. No later insertion or hot mic.
- [ ] **copy_clear:** transcript preview; Copy; Copy original where different;
  Clear removes text. No destination or unsafe/unsupported field automatically
  copies the original transcript and shows “Copied to clipboard.” without taking
  focus. Cancel/Clear and empty speech do not alter the clipboard; no Return/Send.
  With spelling memory enabled, approved replacements apply to the fallback;
  Copy original still gives raw recognition. Correct a just-inserted spelling,
  pause two seconds and open Hello: approve/ignore the candidate, repeat dictation,
  remove a saved pair, clear all, and disable memory. Verify no learning from
  numeric changes, surrounding edits, secure/other fields, manual pastes or forms.
  Verify timeout, app/focus change, new recording and Cancel stop observation.
- [ ] **cleanup:** verify availability indication. When available, run real local
  cleanup with names/numbers/currencies/signs. Review-only, no automatic insertion;
  cancellation/timeout leaves safe state. If unavailable, confirm disabled UI and
  normal dictation; record unavailable-model limitation explicitly.
- [ ] **service_failure:** unavailable speech service/offline failure is visible,
  stops capture and allows retry. Record whether local speech actually works
  offline; do not infer this from supportsOnDeviceRecognition alone.
- [ ] **forms:** use a disposable local form and a test API account. Check provider selection, isolated key save/read/remove,
  and fresh opt-in after switching provider. Exercise each available service with
  disposable data; explicitly record any service not live-tested, never invent a pass. Default off;
  no screen/API access in normal mode. Save/check/remove key without logs;
  verify normal dictation still works with form mode off, a missing/invalid key
  and denied screenshot permission. Provider/key changes while idle must preserve
  the normal transcript. Deny and
  recover screen access. Speak single-field intent without focus, then multiple
  labeled answers; observe exact values in correct empty fields and no submission.
  Verify ambiguity/duplicate labels, existing values, secure controls, unsupported
  controls, incomplete responses, API failures and timeout offer Copy. Change page,
  scroll, type/click, switch windows and cancel during capture/request; no late
  writes. Observe partial-write reporting using a form that changes after one fill.
  Inspect network request scope with test content only. No real private page data.
- [ ] **lifecycle:** sleep/wake, audio input change, quit during recording, retry
  after wake. Check light/dark layout, cancel button/VoiceOver labels, and secondary
  display if one is present. Record unavailable hardware scenarios as limitations.

After notarization and private draft staging, test the exact downloaded/extracted
artifact and record downloaded-smoke.json:

- [ ] **launch:** checksum equal, signature verified, staple valid, Gatekeeper
  accepted; open in Finder without bypassing security controls.
- [ ] **microphone:** real speech is captured and stops on release.
- [ ] **insertion:** original supported TextEdit selection is replaced correctly;
  focus change falls back to Copy; no Return/Send.
- [ ] **cancellation:** cancelled recording cannot later insert text.

The automated regressions use injected audio/providers and cannot substitute for
these microphone, permissions and Accessibility observations. Minimum-OS and Intel
compilation are not claims of physical runtime testing on those systems.
