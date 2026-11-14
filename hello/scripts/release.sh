#!/bin/bash
# Build, Developer ID sign, notarize, staple, and verify Hello. Never publishes.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:-}"
BUILD_NUMBER="${2:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || {
  echo "Usage: bash hello/scripts/release.sh <version: 0.1.0> <build: 1>" >&2; exit 1;
}
[[ "$(uname -s)" == "Darwin" ]] || { echo "A Mac with Xcode and Developer ID signing is required." >&2; exit 1; }
: "${HELLO_SIGNING_IDENTITY:?Set HELLO_SIGNING_IDENTITY to your Developer ID Application certificate name.}"
: "${HELLO_NOTARY_PROFILE:?Set HELLO_NOTARY_PROFILE to a configured notarytool Keychain profile.}"
[[ "$HELLO_SIGNING_IDENTITY" == "Developer ID Application:"* ]] || { echo "Developer ID Application identity required." >&2; exit 1; }
TEAM_IDENTIFIER="${HELLO_TEAM_IDENTIFIER:-QA3AY5HLGM}"
SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
[[ -z "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=all)" ]] || {
  echo "Commit source changes before a release so the manifest identifies the exact source." >&2; exit 1;
}
OUTPUT_DIRECTORY="${HELLO_OUTPUT_DIRECTORY:-$HOME/Hello-Releases/$VERSION-b$BUILD_NUMBER}"
[[ ! -e "$OUTPUT_DIRECTORY" ]] || { echo "Output already exists: $OUTPUT_DIRECTORY" >&2; exit 1; }
WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/hello-release.XXXXXX")"
trap 'rm -rf "$WORK_DIRECTORY"' EXIT
mkdir -p "$OUTPUT_DIRECTORY"

bash "$ROOT_DIR/hello/scripts/check.sh"
xcodebuild archive -project "$ROOT_DIR/hello/Hello.xcodeproj" -scheme Hello \
  -configuration Release -archivePath "$WORK_DIRECTORY/Hello.xcarchive" \
  -derivedDataPath "$WORK_DIRECTORY/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$HELLO_SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_IDENTIFIER" ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS=--timestamp SKIP_INSTALL=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
APP_PATH="$WORK_DIRECTORY/Hello.xcarchive/Products/Applications/Hello.app"
[[ -d "$APP_PATH" ]] || { echo "Archive did not contain Hello.app" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")" == "com.markdebartolo.hello" ]] || exit 1
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2> "$OUTPUT_DIRECTORY/signature.txt"
grep -Fq "TeamIdentifier=$TEAM_IDENTIFIER" "$OUTPUT_DIRECTORY/signature.txt"
grep -Fq 'Authority=Developer ID Application:' "$OUTPUT_DIRECTORY/signature.txt"

ditto -c -k --keepParent "$APP_PATH" "$WORK_DIRECTORY/Hello-notary.zip"
xcrun notarytool submit "$WORK_DIRECTORY/Hello-notary.zip" \
  --keychain-profile "$HELLO_NOTARY_PROFILE" --wait --output-format json \
  > "$OUTPUT_DIRECTORY/notarization.json"
python3 - "$OUTPUT_DIRECTORY/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple did not accept the app. See notarization.json; nothing may be published.')
PY
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"
ARTIFACT_NAME="Hello-$VERSION-b$BUILD_NUMBER.zip"
ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_DIRECTORY/$ARTIFACT_NAME"
cp "$ROOT_DIR/hello/RELEASE_NOTES.md" "$OUTPUT_DIRECTORY/RELEASE_NOTES.md"
python3 - "$OUTPUT_DIRECTORY" "$ARTIFACT_NAME" "$SOURCE_COMMIT" "$VERSION" "$BUILD_NUMBER" "$TEAM_IDENTIFIER" <<'PY'
import hashlib, json, pathlib, sys
directory, artifact, source, version, build, team = sys.argv[1:]
root = pathlib.Path(directory)
checksum = hashlib.sha256((root / artifact).read_bytes()).hexdigest()
(root / 'SHA256SUMS').write_text(f'{checksum}  {artifact}\n')
(root / 'release-manifest.json').write_text(json.dumps({
    'product': 'Hello', 'version': version, 'build': build,
    'source_commit': source, 'bundle_identifier': 'com.markdebartolo.hello',
    'team_identifier': team, 'artifact': artifact, 'sha256': checksum,
    'notarization_status': 'Accepted', 'staple_validated': True,
    'gatekeeper_accepted': True, 'manual_smoke_test': 'pending'
}, indent=2) + '\n')
PY
echo "Verified notarized archive: $OUTPUT_DIRECTORY/$ARTIFACT_NAME"
echo "Not published. Complete hello/SMOKE_TEST.md on a signed Mac before publishing."
