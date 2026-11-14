# Signed Mac release checks

Run the signed candidate from `release.sh prepare` through Finder. Never launch an
unsigned build. Record OS version, hardware, app versions, tester, date and literal
observations in signed-smoke.json; see RELEASING.md. No checkbox is pre-passed.

Required checks (the IDs are release-gate keys):

- [ ] **identity:** Hello waveform icon, bundle `com.markdebartolo.hello`, expected
  Developer ID/team and hardened runtime; no effect on existing Dorsal grants.
- [ ] **permissions:** fresh Hello identity prompts once for Microphone and Speech;
  deny/recover each through Settings. Accessibility/Input Monitoring denial is
  visible; Retry works after grants/relaunch. No Screen Recording/Camera prompt.
- [ ] **microphone:** actual spoken test in TextEdit; recording HUD does not take
  focus; first words survive; audio meter responds; release stops microphone.
- [ ] **selection:** replace only a selected word in TextEdit; test caret insertion
  and Unicode/surrogate text. Try Safari textarea and Notes. Unsupported fields
  offer Copy. Record which app/version genuinely supports AX insertion.
- [ ] **focus:** switch field/app or selection, type/click during capture and
  cleanup, including switching away and back. No stale or wrong-field insertion.
- [ ] **secure_field:** password field and Secure Input never receive automatic
  insertion. Use disposable test text, never a real password.
- [ ] **cancellation:** quick tap/release, repeated holds, Escape/Cancel during
  startup, recording, finalization and cleanup. No later insertion or hot mic.
- [ ] **copy_clear:** transcript preview; Copy; Copy original where different;
  Clear removes text. No automatic clipboard replacement or Return/Send.
- [ ] **cleanup:** verify availability indication. When available, run real local
  cleanup with names/numbers/currencies/signs. Review-only, no automatic insertion;
  cancellation/timeout leaves safe state. If unavailable, confirm disabled UI and
  normal dictation; record unavailable-model limitation explicitly.
- [ ] **service_failure:** unavailable speech service/offline failure is visible,
  stops capture and allows retry. Record whether local speech actually works
  offline; do not infer this from supportsOnDeviceRecognition alone.
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
