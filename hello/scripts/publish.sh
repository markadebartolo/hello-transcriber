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
python3 - "$OUT" <<'PY'
import hashlib, json, pathlib, re, sys
r=pathlib.Path(sys.argv[1]); m=json.loads((r/'release-manifest.json').read_text())
assert m['notarization_status']=='Accepted' and m['manual_smoke_test']=='passed'
assert m['staple_validated'] is True and m['gatekeeper_accepted'] is True
assert re.fullmatch(r'Hello-[0-9]+\.[0-9]+\.[0-9]+-b[1-9][0-9]*\.zip',m['artifact'])
assert hashlib.sha256((r/m['artifact']).read_bytes()).hexdigest()==m['sha256']
assert (r/'SHA256SUMS').read_text()==f"{m['sha256']}  {m['artifact']}\n"
assert (r/'RELEASE_NOTES.md').read_text().splitlines()[0]==f"# Hello {m['version']}"
PY
read -r VERSION SOURCE ARTIFACT TEAM < <(python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m["version"],m["source_commit"],m["artifact"],m["team_identifier"])' "$OUT/release-manifest.json")
TAG="hello-v$VERSION"
# Both local and remote annotated/lightweight tags must resolve to the source commit.
[[ "$(git -C "$ROOT_DIR" rev-parse "$TAG^{commit}")" == "$SOURCE" ]]
[[ "$(gh api "repos/$REPO/commits/$TAG" --jq .sha)" == "$SOURCE" ]]
CHECK="$(mktemp -d "${TMPDIR:-/tmp}/hello-publish.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$OUT/$ARTIFACT" "$CHECK"
bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$CHECK/Hello.app" "$TEAM"
xcrun stapler validate "$CHECK/Hello.app"
spctl --assess --type execute --verbose=2 "$CHECK/Hello.app"
python3 "$ROOT_DIR/hello/scripts/verify-smoke.py" "$OUT" signed
if [[ "$MODE" == stage ]]; then
  [[ "$(gh repo view "$REPO" --json isPrivate --jq .isPrivate)" == true ]] || { echo 'Staging requires a private repository.' >&2; exit 1; }
  gh release create "$TAG" --repo "$REPO" --draft --verify-tag --title "Hello $VERSION" \
    --notes-file "$OUT/RELEASE_NOTES.md" "$OUT/$ARTIFACT" "$OUT/SHA256SUMS" \
    "$OUT/release-manifest.json" "$OUT/notarization.json"
  mkdir "$OUT/downloaded"
  gh release download "$TAG" --repo "$REPO" --pattern "$ARTIFACT" --dir "$OUT/downloaded"
  cmp "$OUT/$ARTIFACT" "$OUT/downloaded/$ARTIFACT"
  ditto -x -k "$OUT/downloaded/$ARTIFACT" "$OUT/downloaded"
  bash "$ROOT_DIR/hello/scripts/verify-app.sh" "$OUT/downloaded/Hello.app" "$TEAM"
  xcrun stapler validate "$OUT/downloaded/Hello.app"
  spctl --assess --type execute --verbose=2 "$OUT/downloaded/Hello.app"
  echo 'Private draft staged and exact download verified. Run downloaded smoke before publish.'
else
  python3 "$ROOT_DIR/hello/scripts/verify-smoke.py" "$OUT" downloaded
  [[ "$(gh release view "$TAG" --repo "$REPO" --json isDraft --jq .isDraft)" == true ]]
  # Re-download to ensure staged assets have not changed since smoke testing.
  gh release download "$TAG" --repo "$REPO" --pattern "$ARTIFACT" --dir "$CHECK"
  cmp "$OUT/$ARTIFACT" "$CHECK/$ARTIFACT"
  # Visibility change is deliberately separate, scoped to this NEW repository.
  [[ "$(gh repo view "$REPO" --json isPrivate --jq .isPrivate)" == false ]] || {
    echo "After review, make only $REPO public, then rerun publish." >&2; exit 1;
  }
  gh release edit "$TAG" --repo "$REPO" --draft=false
fi
