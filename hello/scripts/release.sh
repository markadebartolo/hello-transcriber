#!/bin/bash
# prepare: signed candidate only. notarize: requires observed signed smoke evidence.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:?Usage: release.sh prepare VERSION BUILD | notarize RELEASE_DIRECTORY}"
[[ "$(uname -s)" == Darwin ]]
if [[ "$MODE" == prepare ]]; then
  VERSION="${2:?Version required}"; BUILD="${3:?Build required}"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[1-9][0-9]*$ ]]
  : "${HELLO_SIGNING_IDENTITY:?Set a verified Developer ID Application identity}"
  : "${HELLO_OUTPUT_DIRECTORY:?Set an output directory outside the source repository}"
  [[ "$HELLO_SIGNING_IDENTITY" =~ ^Developer\ ID\ Application:.*\ \(([A-Z0-9]{10})\)$ ]]
  TEAM="${BASH_REMATCH[1]}"
  security find-identity -v -p codesigning | grep -Fq "\"$HELLO_SIGNING_IDENTITY\""
  [[ -z "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=all)" ]] || { echo 'Commit all source first.' >&2; exit 1; }
  SOURCE="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  grep -Fxq "# Hello $VERSION" "$ROOT_DIR/hello/RELEASE_NOTES.md"
  OUT="$HELLO_OUTPUT_DIRECTORY"
  [[ ! -e "$OUT" ]] || { echo 'Output exists; use a new build directory.' >&2; exit 1; }
  mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
  case "$OUT/" in "$ROOT_DIR/"*) echo 'Output must be outside the source tree.' >&2; exit 1;; esac
  bash "$ROOT_DIR/hello/scripts/check.sh"
  xcodebuild -quiet archive -project "$ROOT_DIR/hello/Hello.xcodeproj" -scheme Hello \
    -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$OUT/Hello.xcarchive" -derivedDataPath "$OUT/DerivedData" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$HELLO_SIGNING_IDENTITY" DEVELOPMENT_TEAM="$TEAM" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp SKIP_INSTALL=NO \
    ONLY_ACTIVE_ARCH=NO MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD"
  ditto "$OUT/Hello.xcarchive/Products/Applications/Hello.app" "$OUT/Hello.app"
  # License notices travel with the binary as well as the source distribution.
  cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/NOTICES.md" "$ROOT_DIR/third-party/Sparkle-LICENSE.txt" "$OUT/Hello.app/Contents/Resources/"
  codesign --force --sign "$HELLO_SIGNING_IDENTITY" --options runtime --timestamp \
    --entitlements "$ROOT_DIR/hello/Hello.entitlements" "$OUT/Hello.app"
  bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$OUT/Hello.app" "$TEAM"
  cp "$ROOT_DIR/hello/RELEASE_NOTES.md" "$OUT/RELEASE_NOTES.md"
  python3 -I - "$OUT" "$SOURCE" "$VERSION" "$BUILD" "$TEAM" <<'PY'
import datetime, json, pathlib, re, subprocess, sys
out, source, version, build, team = sys.argv[1:]; root = pathlib.Path(out)
hashes = {}
for arch in ('arm64', 'x86_64'):
    result = subprocess.run(['codesign', '-dv', '--verbose=4', '--arch', arch, str(root/'Hello.app')], capture_output=True, text=True, check=True)
    hashes[arch] = re.search(r'^CDHash=(.+)$', result.stderr, re.M)[1]
(root/'release-manifest.json').write_text(json.dumps(dict(product='Hello', version=version, build=build,
    source_commit=source, bundle_identifier='com.markdebartolo.hello', team_identifier=team,
    app_cdhashes=hashes, created_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    notarization_status='not submitted', manual_smoke_test='pending'), indent=2)+'\n')
PY
  printf '%s\n' "Signed candidate: $OUT/Hello.app. Run SMOKE_TEST.md before notarization."
elif [[ "$MODE" == notarize ]]; then
  OUT="$(cd "${2:?Release directory required}" && pwd)"
  : "${HELLO_NOTARY_PROFILE:?Set the existing notarytool Keychain profile name}"
  python3 -I "$ROOT_DIR/hello/scripts/verify-smoke.py" "$OUT" signed
  TEAM="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["team_identifier"])' "$OUT/release-manifest.json")"
  bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$OUT/Hello.app" "$TEAM"
  python3 -I - "$OUT" <<'PY'
import json, pathlib, re, subprocess, sys
root = pathlib.Path(sys.argv[1]); manifest = json.loads((root/'release-manifest.json').read_text())
for arch, checksum in manifest['app_cdhashes'].items():
    result = subprocess.run(['codesign','-dv','--verbose=4','--arch',arch,str(root/'Hello.app')], capture_output=True,text=True,check=True)
    assert re.search(r'^CDHash=(.+)$', result.stderr, re.M)[1] == checksum, 'App changed after smoke test'
PY
  ditto -c -k --keepParent "$OUT/Hello.app" "$OUT/notary-upload.zip"
  xcrun notarytool submit "$OUT/notary-upload.zip" --keychain-profile "$HELLO_NOTARY_PROFILE" \
    --wait --output-format json > "$OUT/notarization.json"
  python3 -I - "$OUT/notarization.json" <<'PY'
import json, sys
assert json.load(open(sys.argv[1])).get('status') == 'Accepted', 'Apple did not accept this app'
PY
  xcrun stapler staple "$OUT/Hello.app"
  xcrun stapler validate "$OUT/Hello.app"
  bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$OUT/Hello.app" "$TEAM"
  spctl --assess --type execute --verbose=2 "$OUT/Hello.app"
  ARTIFACT="$(python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); print("Hello-"+m["version"]+"-b"+m["build"]+".zip")' "$OUT/release-manifest.json")"
  ditto -c -k --keepParent "$OUT/Hello.app" "$OUT/$ARTIFACT"
  python3 -I - "$OUT" "$ARTIFACT" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1]); artifact=sys.argv[2]
checksum=hashlib.sha256((root/artifact).read_bytes()).hexdigest()
m=json.loads((root/'release-manifest.json').read_text())
m.update(artifact=artifact, sha256=checksum, notarization_status='Accepted', manual_smoke_test='passed',
         staple_validated=True, gatekeeper_accepted=True, downloaded_smoke_test='pending')
(root/'release-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
(root/'SHA256SUMS').write_text(f'{checksum}  {artifact}\n')
PY
  printf '%s\n' "Notarized artifact: $OUT/$ARTIFACT. Not published."
else
  echo 'Unknown release mode.' >&2; exit 1
fi
