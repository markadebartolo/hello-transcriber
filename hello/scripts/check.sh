#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hello-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS and Xcode are required.' >&2; exit 1; }
for script in "$ROOT_DIR"/hello/scripts/*.sh; do bash -n "$script"; done
python3 -I "$ROOT_DIR/hello/scripts/verify-provenance.py"
python3 -I "$ROOT_DIR/hello/Tests/ReleaseGateTests.py"
SWIFT_FLAGS=(-swift-version 6 -warnings-as-errors -module-cache-path "$CHECK_DIR/ModuleCache" -target "$(uname -m)-apple-macos14.2")
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT_DIR/hello/Sources/HelloTranscriptPolicy.swift" \
  "$ROOT_DIR/hello/Tests/HelloTranscriptPolicyTests.swift" -o "$CHECK_DIR/policy-tests"
"$CHECK_DIR/policy-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT_DIR/hello/Sources/HelloRecordingFeedback.swift" \
  "$ROOT_DIR/hello/Tests/HelloRecordingFeedbackTests.swift" -o "$CHECK_DIR/feedback-tests"
"$CHECK_DIR/feedback-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT_DIR/hello/Sources/HelloSpellingMemory.swift" \
  "$ROOT_DIR/hello/Tests/HelloSpellingMemoryTests.swift" -o "$CHECK_DIR/spelling-tests"
"$CHECK_DIR/spelling-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" \
  "$ROOT_DIR/leanring-buddy/BuddyDictationManager.swift" \
  "$ROOT_DIR/leanring-buddy/BuddyTranscriptionProvider.swift" \
  "$ROOT_DIR/leanring-buddy/AppleSpeechTranscriptionProvider.swift" \
  "$ROOT_DIR/leanring-buddy/DorsalLog.swift" \
  "$ROOT_DIR/hello/Tests/HelloLifecycleTests.swift" -o "$CHECK_DIR/lifecycle-tests"
"$CHECK_DIR/lifecycle-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT_DIR/hello/Sources/HelloFormPolicy.swift" \
  "$ROOT_DIR/hello/Sources/HelloAIProvider.swift" "$ROOT_DIR/hello/Sources/HelloFormPlanner.swift" "$ROOT_DIR/hello/Tests/HelloFormTests.swift" -o "$CHECK_DIR/form-tests"
"$CHECK_DIR/form-tests"
xcodebuild -quiet -project "$ROOT_DIR/hello/Hello.xcodeproj" -scheme Hello \
  -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath "$CHECK_DIR/DerivedData" \
  build CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
printf '%s\n' 'Hello universal compile and regression checks passed. The app was not launched or signed.'
