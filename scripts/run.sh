#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
app="build/Build/Products/$configuration/ChatHub.app"
if [[ ! -d "$app" ]]; then bash scripts/build.sh "$configuration"; fi
open "$app"
