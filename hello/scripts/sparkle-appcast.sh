#!/bin/bash
# Generate or verify a signed feed for the exact notarized ZIP in a release directory.
set -euo pipefail
MODE="${1:?Usage: sparkle-appcast.sh generate|verify RELEASE_DIRECTORY EXTRACTED_APP}"
OUT="$(cd "${2:?Release directory required}" && pwd)"
APP="${3:?Extracted app path required}"
: "${HELLO_SPARKLE_BIN:?Point to bin in the verified Sparkle release distribution}"
ACCOUNT=com.markdebartolo.hello
REPO=https://github.com/markadebartolo/hello-transcriber
[[ "$MODE" == generate || "$MODE" == verify ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print SUFeedURL' "$APP/Contents/Info.plist")" == "$REPO/releases/latest/download/appcast.xml" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print SURequireSignedFeed' "$APP/Contents/Info.plist")" == true ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print SUVerifyUpdateBeforeExtraction' "$APP/Contents/Info.plist")" == true ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print SUSignedFeedFailureExpirationInterval' "$APP/Contents/Info.plist")" == 0 ]]
PUBKEY="$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$APP/Contents/Info.plist")"
[[ "$("$HELLO_SPARKLE_BIN/generate_keys" --account "$ACCOUNT" -p)" == "$PUBKEY" ]] || {
  echo 'The Hello Sparkle Keychain signing key does not match this app.' >&2
  exit 1
}
read -r VERSION BUILD ARTIFACT < <(python3 -I - "$OUT" "$APP" <<'PY'
import hashlib, json, pathlib, plistlib, re, sys
root, app = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((root / "release-manifest.json").read_text())
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
version, build, artifact = (manifest[key] for key in ("version", "build", "artifact"))
assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version)
assert re.fullmatch(r"[1-9][0-9]*", build)
assert artifact == f"Hello-{version}-b{build}.zip"
assert manifest["notarization_status"] == "Accepted"
assert manifest["staple_validated"] is True and manifest["gatekeeper_accepted"] is True
assert info["CFBundleIdentifier"] == "com.markdebartolo.hello"
assert info["CFBundleShortVersionString"] == version and info["CFBundleVersion"] == build
assert hashlib.sha256((root / artifact).read_bytes()).hexdigest() == manifest["sha256"]
print(version, build, artifact)
PY
)
PREFIX="$REPO/releases/download/hello-v$VERSION/"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hello-appcast.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FEED="$OUT/appcast.xml"
if [[ "$MODE" == generate ]]; then
  ditto "$OUT/$ARTIFACT" "$WORK/$ARTIFACT"
  "$HELLO_SPARKLE_BIN/generate_appcast" --account "$ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "$PREFIX" --link "$REPO/releases/tag/hello-v$VERSION" "$WORK"
  FEED="$WORK/appcast.xml"
fi
"$HELLO_SPARKLE_BIN/sign_update" --account "$ACCOUNT" --verify "$FEED"
SIGNATURE="$(python3 -I - "$FEED" "$PREFIX$ARTIFACT" "$VERSION" "$BUILD" "$OUT/$ARTIFACT" <<'PY'
import base64, os, sys, xml.etree.ElementTree as ET
feed, url, version, build, artifact = sys.argv[1:]
ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
items = ET.parse(feed).findall("./channel/item")
assert len(items) == 1
item = items[0]
enclosure = item.find("enclosure")
assert enclosure is not None and enclosure.get("url") == url
assert enclosure.get("length") == str(os.path.getsize(artifact))
assert item.findtext(ns + "version", enclosure.get(ns + "version")) == build
assert item.findtext(ns + "shortVersionString", enclosure.get(ns + "shortVersionString")) == version
signature = enclosure.attrib[ns + "edSignature"]
assert len(base64.b64decode(signature, validate=True)) == 64
print(signature)
PY
)"
"$HELLO_SPARKLE_BIN/sign_update" --account "$ACCOUNT" --verify "$OUT/$ARTIFACT" "$SIGNATURE"
if [[ "$MODE" == generate ]]; then
  mv "$FEED" "$OUT/appcast.xml"
fi
