#!/usr/bin/env bash
# Format and lint the whole repo.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
swiftformat .
swiftlint --strict "$@"
