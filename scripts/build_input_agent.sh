#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
DEST="$ROOT/outputs/Kurisu.app/Contents/Helpers/KurisuInputAgent.app"
STAGE="$ROOT/work/build/KurisuInputAgent.app"
# Main-app sources, version and artwork intentionally do not affect this ID.
BUILD_ID=$(
  cat "$ROOT"/KurisuDesktop/InputAgent/*.swift \
      "$ROOT/KurisuDesktop/InputAgent/Info.plist" \
      "$ROOT"/KurisuDesktop/Shared/*.swift "$0" |
    /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
)
CURRENT_ID=$(/usr/libexec/PlistBuddy -c 'Print :InputAgentBuildID' "$DEST/Contents/Info.plist" 2>/dev/null || true)
if [[ "$CURRENT_ID" == "$BUILD_ID" ]] && /usr/bin/codesign --verify --strict "$DEST" 2>/dev/null; then
  print "Reused stable input agent: $BUILD_ID"
  exit 0
fi
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" "${DEST:h}"
xcrun swiftc -swift-version 5 -O \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$ROOT/work/build/module-cache" \
  -framework AppKit -framework Carbon -framework CoreGraphics \
  "$ROOT"/KurisuDesktop/InputAgent/*.swift "$ROOT"/KurisuDesktop/Shared/*.swift \
  -o "$STAGE/Contents/MacOS/KurisuInputAgent"
cp "$ROOT/KurisuDesktop/InputAgent/Info.plist" "$STAGE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :InputAgentBuildID string $BUILD_ID" "$STAGE/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$STAGE"
/usr/bin/codesign --verify --strict "$STAGE"
if [[ -d "$DEST" ]]; then
  # This is the bundled template, never the user's installed authorized copy.
  rm -rf "$DEST"
fi
cp -R "$STAGE" "$DEST"
print "Built stable input agent: $BUILD_ID"
