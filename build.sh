#!/bin/bash
# Eclipse Photography Tool — Build & Run
# Works on macOS 11+ with Command Line Tools (no Xcode app needed)

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
# Pick the best available SDK
SDK_PATH=""
for sdk in \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX14.sdk" \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX13.sdk" \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX12.3.sdk" \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk" \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX12.0.sdk" \
  "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"; do
  if [ -d "$sdk" ]; then SDK_PATH="$sdk"; break; fi
done
if [ -z "$SDK_PATH" ]; then
  echo "❌ No macOS SDK found in CommandLineTools. Run: xcode-select --install"; exit 1
fi
echo "📦 Using SDK: $SDK_PATH"

OUT="$DIR/build/EclipseApp"
APP="$DIR/build/EclipsePhotographyTool.app"

mkdir -p "$DIR/build"

echo "🔨 Building Eclipse Photography Tool..."

/Library/Developer/CommandLineTools/usr/bin/swiftc \
  -sdk "$SDK_PATH" \
  -target x86_64-apple-macos11.0 \
  -framework AppKit \
  -framework MapKit \
  -framework CoreLocation \
  -O \
  -o "$OUT" \
  "$DIR/Sources/EclipseApp/Camera/CameraManager.swift" \
  "$DIR/Sources/EclipseApp/Camera/GPhoto2Bridge.swift" \
  "$DIR/Sources/EclipseApp/Camera/SonyCameraSDKBridge.swift" \
  "$DIR/Sources/EclipseApp/Eclipse/EclipseEngine.swift" \
  "$DIR/Sources/EclipseApp/Eclipse/EclipseMapView.swift" \
  "$DIR/Sources/EclipseApp/Script/ScriptEngine.swift" \
  "$DIR/Sources/EclipseApp/UI/AppEntry.swift" \
  "$DIR/Sources/EclipseApp/UI/MainUI.swift" \
  "$DIR/Sources/EclipseApp/UI/main.swift"

echo "✅ Build successful: $OUT"

# Update app bundle
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT" "$APP/Contents/MacOS/EclipsePhotographyTool"
# Copy real image assets
if [ -d "$DIR/Resources" ]; then
  cp "$DIR/Resources/"*.png "$APP/Contents/Resources/" 2>/dev/null || true
fi

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key><string>EclipsePhotographyTool</string>
<key>CFBundleIdentifier</key><string>com.eclipse.photographytool</string>
<key>CFBundleName</key><string>Eclipse Photography Tool</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSQuitAlwaysKeepsWindows</key><false/>
<key>NSCameraUsageDescription</key><string>Live view and camera control</string>
<key>NSLocationWhenInUseUsageDescription</key><string>Set your observation location for eclipse calculations</string>
</dict>
</plist>
PLIST

echo "🚀 Launching..."
open "$APP"
