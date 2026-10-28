#!/usr/bin/env bash
# Run the tests.
#   ./scripts/test.sh          HeyYouKit package tests (swift test)
#   ./scripts/test.sh --xcode  everything through the HeyYou scheme, including the app-hosted StoreKit tests
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
if [ "${1:-}" = "--xcode" ]; then
  shift
  [ -f Config/Secrets.xcconfig ] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
  xcodegen generate
  xcodebuild -project HeyYou.xcodeproj -scheme HeyYou -configuration Debug -derivedDataPath build/DerivedData \
    -skipMacroValidation -skipPackagePluginValidation test "$@"
else
  cd HeyYouKit && swift test "$@"
fi
