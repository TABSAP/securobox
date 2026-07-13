#!/bin/sh

# Xcode Cloud runs this immediately after cloning the repo, before xcodebuild.
# It is required for Flutter apps: xcodebuild alone cannot build because the
# generated iOS files (Generated.xcconfig, the FlutterGeneratedPluginSwiftPackage
# Swift package, and the CocoaPods workspace) only exist after Flutter tooling
# runs. Without this, the archive fails with
# "FlutterGeneratedPluginSwiftPackage ... doesn't exist in file system".

set -e

echo "=== ci_post_clone: setting up Flutter for Xcode Cloud ==="

# 1. Install Flutter (pinned to the project's version).
FLUTTER_VERSION="3.38.9"
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
flutter --version

# 2. Resolve Dart packages and precache the iOS engine artifacts.
flutter precache --ios
flutter pub get

# 3. Generate the ephemeral iOS files (Generated.xcconfig + the plugin Swift
#    package) without doing a full build or code signing.
flutter build ios --release --config-only --no-codesign

# 4. Install CocoaPods dependencies for the Runner workspace.
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods 2>/dev/null || true
cd ios
pod install

echo "=== ci_post_clone: done ==="
