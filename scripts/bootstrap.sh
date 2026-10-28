#!/usr/bin/env bash
# Install tooling and generate the Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."
brew install xcodegen swiftlint swiftformat
[ -f Config/Secrets.xcconfig ] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
xcodegen generate
