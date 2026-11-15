#!/bin/bash
# Stage a PRIVATE draft for download verification, or publish after recorded smoke.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:?Usage: publish.sh stage|publish RELEASE_DIRECTORY}"
OUT="$(cd "${2:?Release directory required}" && pwd)"
REPO=markadebartolo/hello-transcriber
[[ "$(uname -s)" == Darwin ]]
[[ "$(gh api user --jq .login)" == markadebartolo ]] || { echo 'Personal account required.' >&2; exit 1; }
[[ "$MODE" == stage || "$MODE" == publish ]]
python3 -I - "$OUT" <<'PY'
import hashlib, json, pathlib, re, sys
r=pathlib.Path(sys.argv[1]); m=json.loads((r/'release-manifest.json').read_text())
assert m['notarization_status']=='Accepted' and m['manual_smoke_test']=='passed'
assert m['staple_validated'] is True and m['gatekeeper_accepted'] is True
assert re.fullmatch(r'Hello-[0-9]+\.[0-9]+\.[0-9]+-b[1-9][0-9]*\.zip',m['artifact'])
assert hashlib.sha256((r/m['artifact']).read_bytes()).hexdigest()==m['sha256']
assert (r/'SHA256SUMS').read_text()==f"{m['sha256']}  {m['artifact']}\n"
assert (r/'RELEASE_NOTES.md').read_text().splitlines()[0]==f"# Hello {m['version']}"
PY
read -r VERSION SOURCE ARTIFACT TEAM < <(python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m["version"],m["source_commit"],m["artifact"],m["team_identifier"])' "$OUT/release-manifest.json")
TAG="hello-v$VERSION"
# Both local and remote annotated/lightweight tags must resolve to the source commit.
[[ "$(git -C "$ROOT_DIR" rev-parse "$TAG^{commit}")" == "$SOURCE" ]]
[[ "$(gh api "repos/$REPO/commits/$TAG" --jq .sha)" == "$SOURCE" ]]
CHECK="$(mktemp -d "${TMPDIR:-/tmp}/hello-publish.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$OUT/$ARTIFACT" "$CHECK"
bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$CHECK/Hello.app" "$TEAM"
python3 -I - "$OUT/release-manifest.json" "$CHECK/Hello.app" <<'PYCODE'
import json, pathlib, plistlib, re, subprocess, sys
manifest=json.load(open(sys.argv[1])); app=pathlib.Path(sys.argv[2])
info=plistlib.load(open(app/'Contents/Info.plist','rb'))
assert info['CFBundleShortVersionString']==manifest['version']
assert str(info['CFBundleVersion'])==manifest['build']
for arch, checksum in manifest['app_cdhashes'].items():
    result=subprocess.run(['codesign','-dv','--verbose=4','--arch',arch,str(app)],capture_output=True,text=True,check=True)
    assert re.search(r'^CDHash=(.+)$',result.stderr,re.M)[1]==checksum, 'Artifact differs from smoke-tested app'
PYCODE
xcrun stapler validate "$CHECK/Hello.app"
spctl --assess --type execute --verbose=2 "$CHECK/Hello.app"
python3 -I "$ROOT_DIR/hello/scripts/verify-smoke.py" "$OUT" signed
# Verify both Sparkle signatures and the feed's exact version, ZIP and download URL.
bash "$ROOT_DIR/hello/scripts/sparkle-appcast.sh" verify "$OUT" "$CHECK/Hello.app"
if [[ "$MODE" == stage ]]; then
  gh release create "$TAG" --repo "$REPO" --draft --verify-tag --title "Hello $VERSION" \
    --notes-file "$OUT/RELEASE_NOTES.md" "$OUT/$ARTIFACT" "$OUT/SHA256SUMS" \
    "$OUT/release-manifest.json" "$OUT/notarization.json" "$OUT/appcast.xml"
  mkdir "$OUT/downloaded"
  gh release download "$TAG" --repo "$REPO" --pattern "$ARTIFACT" --pattern appcast.xml --dir "$OUT/downloaded"
  cmp "$OUT/$ARTIFACT" "$OUT/downloaded/$ARTIFACT"
  cmp "$OUT/appcast.xml" "$OUT/downloaded/appcast.xml"
  ditto -x -k "$OUT/downloaded/$ARTIFACT" "$OUT/downloaded"
  bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$OUT/downloaded/Hello.app" "$TEAM"
  xcrun stapler validate "$OUT/downloaded/Hello.app"
  spctl --assess --type execute --verbose=2 "$OUT/downloaded/Hello.app"
  echo 'Private draft staged and exact download verified. Run downloaded smoke before publish.'
else
  python3 -I "$ROOT_DIR/hello/scripts/verify-smoke.py" "$OUT" downloaded
  [[ "$(gh release view "$TAG" --repo "$REPO" --json isDraft --jq .isDraft)" == true ]]
  # Re-download to ensure staged assets have not changed since smoke testing.
  gh release download "$TAG" --repo "$REPO" --pattern "$ARTIFACT" --pattern appcast.xml --dir "$CHECK"
  cmp "$OUT/$ARTIFACT" "$CHECK/$ARTIFACT"
  cmp "$OUT/appcast.xml" "$CHECK/appcast.xml"
  # Visibility change is deliberately separate, scoped to this NEW repository.
  [[ "$(gh repo view "$REPO" --json isPrivate --jq .isPrivate)" == false ]] || {
    echo "After review, make only $REPO public, then rerun publish." >&2; exit 1;
  }
  gh release edit "$TAG" --repo "$REPO" --draft=false --latest
fi
