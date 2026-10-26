#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
if [[ "$configuration" != "Debug" && "$configuration" != "Release" ]]; then
    echo "Usage: scripts/build.sh [Debug|Release]" >&2
    exit 2
fi
xcodebuild -project ChatHub.xcodeproj -scheme ChatHub \
    -configuration "$configuration" -destination 'platform=macOS' \
    -derivedDataPath build build
codesign --verify --deep --strict "build/Build/Products/$configuration/ChatHub.app"
echo "App: $PWD/build/Build/Products/$configuration/ChatHub.app"
