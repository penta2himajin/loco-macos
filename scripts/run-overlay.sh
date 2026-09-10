#!/usr/bin/env bash
# Build and launch loco-macos via LaunchServices so the menu-bar item
# attaches to the interactive Aqua session (plain `swift run` from an
# agent/IDE shell often fails to show NSStatusItem).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build

APP="$ROOT/dist/LocoMacOS.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/debug/LocoMacOS "$APP/Contents/MacOS/LocoMacOS"
chmod +x "$APP/Contents/MacOS/LocoMacOS"

cat > "$APP/Contents/MacOS/LocoMacOS-launcher" <<EOF
#!/bin/bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
export PATH="\${HOME}/repos/loco-bot/target/debug:/usr/local/bin:/opt/homebrew/bin:\$PATH"
exec "\$DIR/LocoMacOS" "\$@"
EOF
chmod +x "$APP/Contents/MacOS/LocoMacOS-launcher"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>LocoMacOS-launcher</string>
	<key>CFBundleIdentifier</key>
	<string>dev.penta2himajin.loco-macos</string>
	<key>CFBundleName</key>
	<string>loco</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticTermination</key>
	<false/>
	<key>NSSupportsSuddenTermination</key>
	<false/>
</dict>
</plist>
EOF

# Replace any previous instance.
pkill -f 'LocoMacOS.app/Contents/MacOS/LocoMacOS' 2>/dev/null || true
pkill -f 'loco serve --backend' 2>/dev/null || true
sleep 0.3

open "$APP"
echo "Launched: $APP"
echo "Look for 🔍/sparkle + “loco” in the menu bar."
