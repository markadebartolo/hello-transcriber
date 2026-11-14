#!/bin/bash
# Publish only an intact, verified artifact after the documented signed-app smoke test.
set -euo pipefail
RELEASE_DIRECTORY="${1:?Usage: bash hello/scripts/publish.sh <verified-release-directory>}"
: "${HELLO_RELEASE_REPO:?Set the intended owner/repository explicitly; no inherited Dorsal destination.}"
[[ "$HELLO_RELEASE_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || exit 1
[[ "$(uname -s)" == "Darwin" ]] || { echo "Verify the signed artifact on a Mac before publishing." >&2; exit 1; }
RELEASE_DIRECTORY="$(cd "$RELEASE_DIRECTORY" && pwd)"
python3 - "$RELEASE_DIRECTORY" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / 'release-manifest.json').read_text())
assert manifest['notarization_status'] == 'Accepted'
assert manifest['staple_validated'] is True and manifest['gatekeeper_accepted'] is True
assert manifest['manual_smoke_test'] == 'passed', 'Complete SMOKE_TEST.md and record passed in the manifest.'
assert pathlib.Path(manifest['artifact']).name == manifest['artifact']
assert hashlib.sha256((root / manifest['artifact']).read_bytes()).hexdigest() == manifest['sha256']
PY
ARTIFACT_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["artifact"])' "$RELEASE_DIRECTORY/release-manifest.json")"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$RELEASE_DIRECTORY/release-manifest.json")"
TAG="hello-v$VERSION"
VERIFY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/hello-publish.XXXXXX")"
trap 'rm -rf "$VERIFY_DIRECTORY"' EXIT
ditto -x -k "$RELEASE_DIRECTORY/$ARTIFACT_NAME" "$VERIFY_DIRECTORY"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIRECTORY/Hello.app"
xcrun stapler validate "$VERIFY_DIRECTORY/Hello.app"
spctl --assess --type execute --verbose=2 "$VERIFY_DIRECTORY/Hello.app"
# Require a pre-existing tag in the intended repository. Do not silently tag unrelated main.
gh api "repos/$HELLO_RELEASE_REPO/git/ref/tags/$TAG" > /dev/null
gh release create "$TAG" --repo "$HELLO_RELEASE_REPO" --verify-tag \
  --title "Hello $VERSION" --notes-file "$RELEASE_DIRECTORY/RELEASE_NOTES.md" \
  "$RELEASE_DIRECTORY/$ARTIFACT_NAME" "$RELEASE_DIRECTORY/SHA256SUMS" \
  "$RELEASE_DIRECTORY/release-manifest.json" "$RELEASE_DIRECTORY/notarization.json"
