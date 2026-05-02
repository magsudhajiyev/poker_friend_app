#!/bin/sh
set -e

# Xcode Cloud post-clone script
# Installs Flutter and runs pod install so Pods xcfilelists are available for the build.

FLUTTER_VERSION="3.38.10"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"

echo "=== Installing Flutter $FLUTTER_VERSION ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
curl -sLO "$FLUTTER_URL"
unzip -qo "flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
export PATH="$CI_PRIMARY_REPOSITORY_PATH/flutter/bin:$PATH"

echo "=== Flutter doctor ==="
flutter doctor -v

echo "=== Flutter pub get ==="
flutter pub get

echo "=== Pod install ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Done ==="
