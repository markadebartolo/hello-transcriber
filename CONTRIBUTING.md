# Contributing

Open an issue describing a reproducible problem without transcripts or private
field contents. Include macOS/Xcode versions, hardware, affected app version and
whether the issue involves permissions, focus, capture or transcription.

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

CI is compile/test-only. Maintainers perform the signed Mac checks and release gates
in hello/RELEASING.md. Never mark a manual check passed based only on code inspection.
