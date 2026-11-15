# Contributing

## Build and test

Use macOS, Xcode 16 or later and Swift 6. Use Xcode 26 or later to build with
Foundation Models support for punctuation review. Xcode resolves the pinned
Sparkle dependency. A clean checkout builds independently of Dorsal and without
API credentials.

```sh
git clone https://github.com/markadebartolo/hello-transcriber.git
cd hello-transcriber
bash hello/scripts/check.sh
```

The check runs regression tests, verifies module checksums, and compiles for
Apple silicon and Intel. Open `hello/Hello.xcodeproj`, choose the **Hello**
scheme, and select your own signing team for local development. Use your own
OpenAI API key to test live dictation.

## Report a problem

Open an issue with the steps to reproduce, your macOS version and hardware, the
Hello version and build, and the destination app and version when relevant. For
build issues, include your Xcode version. Use disposable text and keep
transcripts, screenshots of sensitive fields, and API keys out of reports.

## Submit a change

Use a feature/fix branch and a pull request. Run `bash hello/scripts/check.sh`.
Meaningful regressions belong at the capture/provider boundary (cancelled startup,
late callbacks, finalization, failure cleanup) or the text policy. Do not introduce
mock implementations in the shipping capture path. Keep UI state on the main actor;
Speech callbacks and audio capture have independent execution contexts.

Preserve upstream notices and hashes. If a shared module changes, explain the
necessary fix in MODIFICATIONS.md and update SOURCE_CHECKSUMS.json. Never replace the
original hashes in SOURCE_PROVENANCE.json. Keep unrelated Dorsal files, credentials,
private service code, personal test recordings and unsigned binaries out of commits.

Contributions must be yours to license under MIT or include a compatible license
and attribution. Do not remove third-party notices. Keep the no-Return/Send,
secure-field exclusion and Copy fallback invariants. Punctuation proposals require
human review; do not claim token equality guarantees meaning.

CI runs compile and regression checks. The [signed Mac checks](hello/SMOKE_TEST.md)
and [release procedure](hello/RELEASING.md) cover device testing and publication.
