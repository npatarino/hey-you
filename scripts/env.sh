# Sourced by the other scripts. Picks an Xcode even if xcode-select points at the Command Line Tools.
if ! xcodebuild -version >/dev/null 2>&1; then
  candidate=$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -v Xcodes.app | sort -r | head -1 || true)
  if [ -n "${candidate}" ]; then
    export DEVELOPER_DIR="${candidate}/Contents/Developer"
  fi
fi
