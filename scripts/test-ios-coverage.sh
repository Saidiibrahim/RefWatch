#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-/tmp/RefWatch-iOS.xcresult}"

if [ -e "$RESULT_BUNDLE_PATH" ]; then
  rm -rf "$RESULT_BUNDLE_PATH"
fi

if [ -n "${IOS_DESTINATION:-}" ]; then
  DESTINATION="$IOS_DESTINATION"
else
  DEST_ID="$(
    python3 - <<'PY'
import json
import subprocess
import sys

def sh(args: list[str]) -> str:
    return subprocess.check_output(args, text=True).strip()

devices = json.loads(sh(["xcrun", "simctl", "list", "devices", "-j"])).get("devices") or {}
candidates = []
for runtime, devs in devices.items():
    if "iOS" not in runtime:
        continue
    for dev in devs or []:
        if not dev.get("isAvailable"):
            continue
        name = str(dev.get("name") or "")
        udid = str(dev.get("udid") or "")
        if not udid or not name.startswith("iPhone"):
            continue
        candidates.append((name, udid))

def rank(name: str) -> tuple[int, str]:
    if "iPhone 16" in name:
        return (0, name)
    if "iPhone 15" in name:
        return (1, name)
    return (2, name)

candidates.sort(key=lambda it: rank(it[0]))
if not candidates:
    print("", end="")
    sys.exit(0)
print(candidates[0][1])
PY
  )"

  if [ -z "$DEST_ID" ]; then
    echo "No available iOS simulator found."
    exit 1
  fi

  DESTINATION="platform=iOS Simulator,id=$DEST_ID"
fi

xcodebuild test \
  -project "$PROJECT_ROOT/RefWatch.xcodeproj" \
  -scheme "RefWatchiOS" \
  -destination "$DESTINATION" \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE_PATH"

xcrun xccov view --report --only-targets "$RESULT_BUNDLE_PATH"
