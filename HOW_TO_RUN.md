# How to Build & Run the Eclipse Photography Tool

## Prerequisites
- **macOS 11+** (Big Sur or later)
- **Xcode Command Line Tools** installed:
  ```bash
  xcode-select --install
  ```

## Build & Launch (One Command)
```bash
cd /Users/jai/Documents/Eclipse/EclipseApp
bash build.sh
```

This will:
1. Find your macOS SDK automatically
2. Compile all Swift source files
3. Create `EclipsePhotographyTool.app` in the `build/` folder
4. Launch the app

## Manual Build (if needed)
```bash
cd /Users/jai/Documents/Eclipse/EclipseApp

SDK=$(xcrun --show-sdk-path)

swiftc \
  -sdk "$SDK" \
  -target x86_64-apple-macos11.0 \
  -framework AppKit \
  -framework MapKit \
  -framework CoreLocation \
  -O \
  -o build/EclipseApp \
  Sources/EclipseApp/Camera/CameraManager.swift \
  Sources/EclipseApp/Camera/GPhoto2Bridge.swift \
  Sources/EclipseApp/Camera/SonyCameraSDKBridge.swift \
  Sources/EclipseApp/Eclipse/EclipseEngine.swift \
  Sources/EclipseApp/Eclipse/EclipseMapView.swift \
  Sources/EclipseApp/Script/ScriptEngine.swift \
  Sources/EclipseApp/UI/AppEntry.swift \
  Sources/EclipseApp/UI/MainUI.swift \
  Sources/EclipseApp/UI/main.swift

./build/EclipseApp
```

## Re-launch Without Rebuilding
```bash
open /Users/jai/Documents/Eclipse/EclipseApp/build/EclipsePhotographyTool.app
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No macOS SDK found` | Run `xcode-select --install` |
| App doesn't appear | Click the app icon in the Dock |
| `xcrun: error` | Run `sudo xcode-select --reset` |

## Notes
- No Xcode.app required — Command Line Tools are sufficient
- The app uses `swiftc` directly, not `swift build` (avoids XCTest dependency)
- Camera features require a Sony/Canon camera connected via USB
