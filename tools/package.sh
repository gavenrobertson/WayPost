#!/bin/sh
# Builds the release zip: the four addon folders, ready to unzip into Interface/AddOns.
# usage: tools/package.sh [version]
set -e
cd "$(dirname "$0")/.."
VERSION="${1:-$(sed -n 's/^## Version: //p' Waypost/Waypost.toc)}"
OUT="dist/Waypost-${VERSION}.zip"
mkdir -p dist
rm -f "$OUT"
cp LICENSE CREDITS.md Waypost/
zip -qr "$OUT" Waypost Waypost_Routes_Alliance Waypost_Routes_Horde Waypost_Routes_Extras -x "*.DS_Store"
rm -f Waypost/LICENSE Waypost/CREDITS.md
echo "$OUT"
