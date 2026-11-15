# Maintainer release procedure

Use only `markadebartolo/hello-transcriber`. Authenticate the personal account with
`gh api user`; verify `login=markadebartolo` and `type=User`. Never push or change
visibility/license in dorsal-beta. Repository creation/release staging uses `gh`
because the connected GitHub tool does not offer these operations.

1. Review the source/license scope, provenance, secrets and scripts. Run check.sh.
   Commit substantive work with actual dates. CI must pass. Match release notes to
   the intended version, and commit all source before creating a candidate.
2. Read `security find-identity -v -p codesigning`. Set `HELLO_SIGNING_IDENTITY` to
   the exact valid **Developer ID Application** name. No default team is assumed.
   Set `HELLO_OUTPUT_DIRECTORY` to a new directory outside the repository.
3. Run `bash hello/scripts/release.sh prepare "$VERSION" "$BUILD"` with the
   intended version and build number. This creates a universal,
   hardened, timestamped signed app and manifest, but does not submit or publish.
   Licenses are bundled in Resources and covered by the final signature.
4. Open the signed app through Finder. Run SMOKE_TEST.md and record **observed**
   checks in `signed-smoke.json` beside the manifest. The schema is below. Record
   failures/pending honestly; the next stage refuses them. Never change a failure
   to passed merely to unblock the script.
5. Set `HELLO_NOTARY_PROFILE` to your existing notarytool Keychain profile name.
   If missing, run `xcrun notarytool store-credentials Hello-Notary` in your own
   Terminal and complete Apple's interactive credential prompts. Do not place
   passwords/tokens in commands, git, logs, or chat. Restore existing credentials
   where possible; an app-specific password may need to be created in your Apple
   account by you. The script never extracts credentials.
6. Run `bash hello/scripts/release.sh notarize "$HELLO_OUTPUT_DIRECTORY"`. Require
   Accepted, staple/validate, verify signature and Gatekeeper. Preserve the result
   JSON and checksums. Use an increasing build number and a new release version.
   Generate the Sparkle feed for this exact stapled ZIP. Obtain the Sparkle tools
   from the matching official release and verify the download against GitHub's
   SHA-256 digest. Set `HELLO_SPARKLE_BIN` to the verified distribution's `bin`
   directory, then run:
   `bash hello/scripts/sparkle-appcast.sh generate "$HELLO_OUTPUT_DIRECTORY" "$HELLO_OUTPUT_DIRECTORY/Hello.app"`.
   It uses Keychain account `com.markdebartolo.hello` and verifies the public key
   against the app, then verifies the feed signature and ZIP signature. Keep the
   existing key for future releases. Back it up securely outside the repository.
   Failure means no distribution. The script deliberately
   preserves the signed candidate/work for diagnosis rather than deleting it.
7. Create an annotated `hello-v$VERSION` tag at the manifest's exact source commit
   and push only to Hello. Keep the release unpublished during staging. Run
   `bash hello/scripts/publish.sh stage "$HELLO_OUTPUT_DIRECTORY"` to create a
   draft release, download the exact ZIP and appcast, compare bytes and reverify them.
8. Open `downloaded/Hello.app` through Finder (quit the prior copy first), repeat
   microphone/insertion/cancellation checks, and record `downloaded-smoke.json`.
   Record the exact artifact checksum. Never distribute unsigned CI output.
9. Review source and release assets and verify that the Hello repository is public.
   Run `bash hello/scripts/publish.sh publish "$HELLO_OUTPUT_DIRECTORY"`.
   The script checks the remote tag's resolved commit, evidence, signature,
   notarization ticket, Gatekeeper and a fresh download before publishing the draft.
10. Verify public repository/release links and checksums. Check the public
    `releases/latest/download/appcast.xml` resolves to the published signed feed.
    From a prior Sparkle-enabled build, check, approve and install an update,
    then verify the version, relaunch and retained settings. The first public
    Sparkle build can confirm a working feed and an up-to-date result. Report actual test scope,
    limitations, notarization request/status and matching tag/source commit.

## Evidence schema

`source_commit` and `app_cdhashes` must be copied from the candidate manifest.
`date`, `system`, `tester` and observations must describe the actual test, not planned
behavior. All named required signed cases are listed in verify-smoke.py; see
SMOKE_TEST.md. Downloaded evidence replaces `app_cdhashes` with `artifact_sha256` and
uses checks `launch`, `microphone`, `insertion`, `cancellation`.

```json
{
  "source_commit": "exact candidate commit",
  "app_cdhashes": {"arm64": "signed hash", "x86_64": "signed hash"},
  "date": "actual ISO date/time",
  "system": "macOS version, Mac model, affected app versions",
  "tester": "person/agent who observed these checks",
  "checks": {
    "identity": {"result": "pending", "observation": ""}
  },
  "limitations": ["Hardware/OS scenarios not performed"]
}
```

A hash/evidence gate binds the tested binary but is not an independent attestation
that a human performed a test. Maintainers must supply truthful observations.
