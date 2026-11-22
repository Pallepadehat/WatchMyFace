#!/bin/zsh
# Everything that has to hold before a release, in one go. release.sh runs it first; run it yourself any time.
#
#   1. Lint    swift format, strict
#   2. Tests   FaceKit's tests: matching, the unlock guardrails, enrollment, blinks
#   3. Build   the app, Release and Debug, without warnings in our own code
#
# The app's camera, notch and lock screen parts need a person in front of a Mac; see .github/CONTRIBUTING.md,
# "Testing by hand", for the checklist.
set -uo pipefail
cd "$(dirname "$0")/.."

# `swift test` and xcodebuild need Xcode, not just the Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p 2>/dev/null)" != *Xcode*.app* ]]; then
  XCODE=$(ls -d /Applications/Xcode*.app 2>/dev/null | sort | tail -1)
  [[ -n "$XCODE" ]] || { echo "This needs Xcode (27 or later)."; exit 1; }
  export DEVELOPER_DIR="$XCODE/Contents/Developer"
fi

mkdir -p build/check
RESULTS=()
FAILED=0
step() {  # step <name> <command…>: runs it, keeps its output in build/check, and notes how it went
  local name=$1; shift
  local log="build/check/${name// /-}.log"
  print -P "\n%B▶ $name%b"
  local started=$SECONDS
  "$@" 2>&1 | tee "$log"
  local code=${pipestatus[1]}
  local took=$(( SECONDS - started ))
  if (( code == 0 )); then
    RESULTS+=("✅ $name (${took}s)")
  else
    RESULTS+=("❌ $name (${took}s), see $log")
    FAILED=1
  fi
}

lint() { swift format lint --strict -r Sources Packages/FaceKit scripts; }
tests() { (cd Packages/FaceKit && swift test); }
# Ad hoc signed and without the hardened runtime, so it builds on any Mac.
build_app() {
  local configuration
  for configuration in Release Debug; do
    echo "Building $configuration…"
    xcodebuild build -project WatchMyFace.xcodeproj -scheme WatchMyFace -configuration $configuration \
      -derivedDataPath build/check/DerivedData -destination 'platform=macOS' \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO \
      > "build/check/xcodebuild-$configuration.log" 2>&1 || {
      grep -E "error:" "build/check/xcodebuild-$configuration.log" | sort -u | head -20
      return 1
    }
    if grep -E "warning: .*(Sources/WatchMyFace|FaceKit)/" "build/check/xcodebuild-$configuration.log" | sort -u | grep .; then
      echo "The $configuration build has warnings."
      return 1
    fi
  done
}

step "Lint" lint
step "Tests" tests
step "Build" build_app

print -P "\n%BSummary%b"
for result in "${RESULTS[@]}"; do echo "  $result"; done
if (( FAILED )); then
  echo "\nSomething needs a look before this can be released."
  exit 1
fi
echo "\nAll good."
