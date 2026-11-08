#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
APP="$ROOT/outputs/Kurisu.app"
mkdir -p "$ROOT/work/build" "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -O \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$ROOT/work/build/module-cache" \
  -framework AppKit -framework SwiftUI -framework CoreGraphics \
  -framework ServiceManagement -framework ImageIO -framework Carbon -framework IOKit -framework Security \
  "$ROOT"/KurisuDesktop/Sources/*.swift "$ROOT"/KurisuDesktop/Shared/*.swift \
  -o "$ROOT/work/build/Kurisu"
# Only stop this exact app after compilation succeeds; do not overwrite a
# running signed executable or close another copy the user may have installed.
xcrun swift -e '
import AppKit
let target = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
for app in NSRunningApplication.runningApplications(withBundleIdentifier: "local.kurisu.desktop")
where app.bundleURL?.standardizedFileURL == target {
    if !app.terminate() { continue }
    let deadline = Date().addingTimeInterval(5)
    while !app.isTerminated && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    if !app.isTerminated {
        fputs("Kurisu is still running; quit it before rebuilding.\n", stderr)
        exit(1)
    }
}
' "$APP"
zsh "$ROOT/scripts/build_input_agent.sh"
cp "$ROOT/work/build/Kurisu" "$APP/Contents/MacOS/Kurisu"
cp "$ROOT/KurisuDesktop/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT"/KurisuDesktop/Resources/* "$APP/Contents/Resources/"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
print "Built: $APP"
