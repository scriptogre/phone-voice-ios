#!/usr/bin/env bash
# Build, sign, and install PhoneVoice on Chris's iPhone from the MacBook over Tailscale.
set -euo pipefail
MAC=macbook
DEV=EE26ACD3-B3E3-5064-AB2F-E5DE40D874CE
rsync -a --delete --exclude .git --exclude build "$(dirname "$0")/" $MAC:~/Documents/Codex/phone-voice-ios/
ssh $MAC 'export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin; cd ~/Documents/Codex/phone-voice-ios
  xcodegen generate >/dev/null
  xcodebuild -project PhoneVoice.xcodeproj -scheme PhoneVoice -destination generic/platform=iOS \
    -derivedDataPath build -allowProvisioningUpdates build 2>&1 | tail -3
  xcrun devicectl device install app --device '$DEV' build/Build/Products/Debug-iphoneos/PhoneVoice.app 2>&1 | tail -2'
