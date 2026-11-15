#!/bin/bash
# Verify identity and signature without launching an application.
set -euo pipefail
APP="${1:?App path required}"
TEAM="${2:?Expected verified team required}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")" == com.markdebartolo.hello ]]
codesign --verify --deep --strict --verbose=2 "$APP"
DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1)"
grep -Fxq "TeamIdentifier=$TEAM" <<< "$DETAILS"
grep -Fq 'Authority=Developer ID Application:' <<< "$DETAILS"
grep -Eq 'flags=.*\(.*runtime.*\)' <<< "$DETAILS"
if /usr/libexec/PlistBuddy -c 'Print SUFeedURL' "$APP/Contents/Info.plist" >/dev/null 2>&1; then
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
  HELPERS="$SPARKLE/Versions/Current"
  for component in "$SPARKLE" "$HELPERS/Autoupdate" "$HELPERS/Updater.app" \
      "$HELPERS/XPCServices/Installer.xpc" "$HELPERS/XPCServices/Downloader.xpc"; do
    DETAILS="$(codesign -dv --verbose=4 "$component" 2>&1)"
    grep -Fxq "TeamIdentifier=$TEAM" <<< "$DETAILS"
    grep -Fq 'Authority=Developer ID Application:' <<< "$DETAILS"
    grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)' <<< "$DETAILS"
    grep -q '^Timestamp=' <<< "$DETAILS"
  done
fi
ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign -d --entitlements :- "$APP" > "$ENTITLEMENTS" 2>/dev/null
python3 -I - "$ENTITLEMENTS" <<'PY'
import plistlib, sys
entitlements = plistlib.load(open(sys.argv[1], 'rb'))
assert entitlements == {'com.apple.security.device.audio-input': True}, entitlements
PY
