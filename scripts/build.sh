#!/usr/bin/env bash
# Build the app (Debug).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
[ -f Config/Secrets.xcconfig ] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
xcodegen generate
xcodebuild -project HeyYou.xcodeproj -scheme HeyYou -configuration Debug -derivedDataPath build/DerivedData build "$@"
