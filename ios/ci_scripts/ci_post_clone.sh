#!/bin/sh
set -e

# Xcode Cloud post-clone script
# Installs Flutter and runs pod install so Pods xcfilelists are available for the build.

FLUTTER_VERSION="3.38.10"

# CI_PRIMARY_REPOSITORY_PATH is set by Xcode Cloud; fall back to script location
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
echo "=== Repo root: $REPO_ROOT ==="

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  FLUTTER_FILE="flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
else
  FLUTTER_FILE="flutter_macos_${FLUTTER_VERSION}-stable.zip"
fi
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${FLUTTER_FILE}"

echo "=== Installing Flutter $FLUTTER_VERSION ($ARCH) ==="
cd "$REPO_ROOT"
curl -sLO "$FLUTTER_URL"
unzip -qo "$FLUTTER_FILE"
export PATH="$REPO_ROOT/flutter/bin:$PATH"

echo "=== Flutter version ==="
flutter --version

echo "=== Flutter pub get ==="
flutter pub get

echo "=== Pod install ==="
cd "$REPO_ROOT/ios"
pod install

echo "=== Done ==="
