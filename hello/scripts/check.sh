#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hello-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Hello requires macOS and Xcode for compile and policy validation." >&2
  exit 1
fi
xcrun swiftc "$ROOT_DIR/hello/Sources/HelloTranscriptPolicy.swift" \
  "$ROOT_DIR/hello/Tests/HelloTranscriptPolicyTests.swift" -o "$CHECK_DIR/policy-tests"
"$CHECK_DIR/policy-tests"
xcodebuild -project "$ROOT_DIR/hello/Hello.xcodeproj" -scheme Hello \
  -configuration Debug -derivedDataPath "$CHECK_DIR/DerivedData" \
  build CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES
echo "Hello compile and policy checks passed. The app was not launched or signed."
