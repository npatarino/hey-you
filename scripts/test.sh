#!/usr/bin/env bash
# Run the HeyYouKit test suite.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
cd HeyYouKit && swift test "$@"
