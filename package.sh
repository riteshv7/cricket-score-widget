#!/bin/bash
# Package the Maidan widget as a standalone macOS .app bundle

APP_NAME="Maidan"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_SOURCE="/Users/riteshverma/.gemini/antigravity/scratch/MaidanAppIcon.png"

echo "🧹 Cleaning previous build..."
rm -rf "${BUNDLE_DIR}"
rm -rf AppIcon.iconset
rm -f AppIcon.icns

echo "🏗️ Creating .app directory structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "📦 Copying menu bar icon..."
cp "Sources/Maidan/MaidanFieldIcon.png" "${RESOURCES_DIR}/"


echo "🎨 Creating iconset and generating multi-size AppIcon.icns..."
mkdir -p AppIcon.iconset

# Resize images using macOS sips (forcing PNG format conversion)
sips -s format png -z 16 16     "${ICON_SOURCE}" --out AppIcon.iconset/icon_16x16.png     >/dev/null 2>&1
sips -s format png -z 32 32     "${ICON_SOURCE}" --out AppIcon.iconset/icon_16x16@2x.png  >/dev/null 2>&1
sips -s format png -z 32 32     "${ICON_SOURCE}" --out AppIcon.iconset/icon_32x32.png     >/dev/null 2>&1
sips -s format png -z 64 64     "${ICON_SOURCE}" --out AppIcon.iconset/icon_32x32@2x.png  >/dev/null 2>&1
sips -s format png -z 128 128   "${ICON_SOURCE}" --out AppIcon.iconset/icon_128x128.png   >/dev/null 2>&1
sips -s format png -z 256 256   "${ICON_SOURCE}" --out AppIcon.iconset/icon_128x128@2x.png >/dev/null 2>&1
sips -s format png -z 256 256   "${ICON_SOURCE}" --out AppIcon.iconset/icon_256x256.png   >/dev/null 2>&1
sips -s format png -z 512 512   "${ICON_SOURCE}" --out AppIcon.iconset/icon_256x256@2x.png >/dev/null 2>&1
sips -s format png -z 512 512   "${ICON_SOURCE}" --out AppIcon.iconset/icon_512x512.png   >/dev/null 2>&1
sips -s format png -z 1024 1024 "${ICON_SOURCE}" --out AppIcon.iconset/icon_512x512@2x.png >/dev/null 2>&1


# Compile iconset to icns
iconutil -c icns AppIcon.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
rm -rf AppIcon.iconset

echo "💻 Compiling Swift source files..."
swiftc "Sources/Maidan/Config.swift" \
       "Sources/Maidan/Models.swift" \
       "Sources/Maidan/APIClient.swift" \
       "Sources/Maidan/MatchSelector.swift" \
       "Sources/Maidan/MatchService.swift" \
       "Sources/Maidan/Maidan.swift" \
       -o "${MACOS_DIR}/${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed."
    exit 1
fi

echo "📝 Generating Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.riteshv.maidan</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ App packaged successfully: ${BUNDLE_DIR}"
echo "You can double-click ${BUNDLE_DIR} to launch the app natively!"
echo "Drag it to your /Applications folder to make it permanent."
