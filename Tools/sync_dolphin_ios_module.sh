#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOLPHIN_DIR="${DOLPHIN_DIR:-/Users/sb/project/dolphin-ios}"
DOLPHIN_APP="${DOLPHIN_APP:-}"

if [ -z "$DOLPHIN_APP" ]; then
  DOLPHIN_APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/Build/Products/Release (Non-Jailbroken)-iphoneos/DolphiniOS.app" \
    -type d \
    -print0 2>/dev/null | xargs -0 ls -td 2>/dev/null | head -1 || true)"
fi

if [ ! -d "$DOLPHIN_APP" ]; then
  echo "Missing Dolphin app bundle: $DOLPHIN_APP" >&2
  echo "Build it from $DOLPHIN_DIR first." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/Natives/resources/Frameworks"
DOLPHIN_LIBRARY="$DOLPHIN_DIR/build-iphoneos-Release/Source/iOS/Library/libdolphin.dylib"
if [ ! -f "$DOLPHIN_LIBRARY" ]; then
  DOLPHIN_LIBRARY="$DOLPHIN_APP/Frameworks/libdolphin.dylib"
fi
cp "$DOLPHIN_LIBRARY" "$ROOT_DIR/Natives/resources/Frameworks/libdolphin.dylib"

rm -rf "$ROOT_DIR/Natives/resources/Sys"
if [ -d "$DOLPHIN_APP/Sys" ]; then
  cp -R "$DOLPHIN_APP/Sys" "$ROOT_DIR/Natives/resources/Sys"
fi

MODULE_DIR="$ROOT_DIR/Modules/dolphin"
RESOURCE_DIR="$MODULE_DIR/Resources"
rm -rf "$RESOURCE_DIR"
mkdir -p "$RESOURCE_DIR"

for item in \
  AboutSettings.storyboardc \
  ActionReplay.storyboardc \
  Assets.car \
  ButtonMapping.storyboardc \
  ConfigSettings.storyboardc \
  ControllersSettings.storyboardc \
  DebugSettings.storyboardc \
  DefaultPreferences.plist \
  Emulation.storyboardc \
  ExternalDisplay.storyboardc \
  Gecko.storyboardc \
  GraphicsSettings.storyboardc \
  JitWait.nib \
  Logger.ini \
  Main.storyboardc \
  NKitWarning.nib \
  SettingsRoot.storyboardc \
  SoftwareList.storyboardc \
  SoftwareProperties.storyboardc \
  Sys \
  TCClassicWiiPad.nib \
  TCGameCubePad.nib \
  TCSidewaysWiiPad.nib \
  TCWiiPad.nib \
  WiiSystemUpdate.storyboardc \
  en.lproj \
  ja.lproj; do
  if [ -e "$DOLPHIN_APP/$item" ]; then
    cp -R "$DOLPHIN_APP/$item" "$RESOURCE_DIR/"
  fi
done

echo "Synced Dolphin module resources from $DOLPHIN_APP"
