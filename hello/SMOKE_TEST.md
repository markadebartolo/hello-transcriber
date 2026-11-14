# Signed Mac release checks

Run against the exact Developer ID-signed artifact produced by `scripts/release.sh`. Open Hello through Finder, not as a child of Terminal. Do not run an unsigned CI app on a Mac with existing privacy grants.

- [ ] Hello has its own icon and `com.markdebartolo.hello` identity. Existing Dorsal still launches and retains its grants.
- [ ] On a fresh account: audio setup prompts once; denying microphone or speech permission produces a clear recovery path; granting access through Settings enables dictation.
- [ ] Accessibility/Input Monitoring denial is visible; retry works after granting. Only the requested access is needed; no Screen Recording prompt.
- [ ] Hold Control + Option in TextEdit: status appears without focus theft, first words survive, release finalizes, and text replaces only the selected range.
- [ ] Quick tap/release, rapid repeated holds, Cancel while recording, Cancel while cleaning, and empty audio neither insert stale text nor leave the microphone running.
- [ ] Change the focused field/app or selected range while recording/cleaning: no text is inserted into the new field; transcript remains available to copy.
- [ ] Password fields and Secure Input never receive transcript insertion.
- [ ] Test Safari web text area and a target app such as Notes or Slack. Unsupported text fields offer Copy, without clipboard replacement or synthetic Return/Send.
- [ ] On supported hardware, enable punctuation cleanup. Names, amounts, signs and percentages survive; Copy original works if formatting changed.
- [ ] Without Apple Intelligence or on macOS 14/15, cleanup is disabled and transcription still works.
- [ ] Test unavailable speech service/offline behavior, wake from sleep, secondary display, dark/light appearance, VoiceOver labels, and Quit during dictation.
- [ ] `codesign --verify`, `stapler validate`, and `spctl --assess` pass against the downloaded/extracted archive.

Record OS version, Mac model, tested app versions, result, tester, and date alongside the release artifact. Change `manual_smoke_test` to `passed` in its `release-manifest.json` only after these checks succeed.
