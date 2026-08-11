#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

VERSION="0.1.0"
PACKAGE_NAME="custom-screensaver-${VERSION}-kindlehf.zip"

DIST="$ROOT/dist"
STAGING="$ROOT/build/package-zip"
OUTPUT="$ROOT/release"

APP="$STAGING/extensions/custom-screensaver"

for file in \
    "$DIST/screensaver_shield" \
    "$DIST/fbink_hf" \
    "$DIST/build-metadata.txt" \
    "$ROOT/LICENSE"
do
    if [ ! -f "$file" ]; then
        echo "Missing required file: $file" >&2
        exit 1
    fi
done

rm -rf "$STAGING"

mkdir -p \
    "$STAGING/documents" \
    "$APP/bin" \
    "$APP/licenses/FBInk" \
    "$STAGING/screensavers" \
    "$OUTPUT"

cp \
    "$ROOT/packaging/zip/documents/Custom Screensaver.sh" \
    "$STAGING/documents/Custom Screensaver.sh"

cp \
    "$ROOT/packaging/zip/screensavers/README.txt" \
    "$STAGING/screensavers/README.txt"

cp \
    "$ROOT/src/scripts/custom_ss_daemon.sh" \
    "$APP/custom_ss_daemon.sh"

cp \
    "$ROOT/src/scripts/toggle.sh" \
    "$APP/toggle.sh"

cp \
    "$ROOT/THIRD_PARTY_NOTICES.md" \
    "$APP/THIRD_PARTY_NOTICES.md"

cp \
    "$ROOT/licenses/FBInk/LICENSE" \
    "$APP/licenses/FBInk/LICENSE"

cp \
    "$ROOT/licenses/FBInk/CREDITS" \
    "$APP/licenses/FBInk/CREDITS"

cp \
    "$DIST/screensaver_shield" \
    "$APP/bin/screensaver_shield"

cp \
    "$DIST/fbink_hf" \
    "$APP/bin/fbink_hf"

cp \
    "$DIST/build-metadata.txt" \
    "$APP/build-metadata.txt"

cp \
    "$ROOT/LICENSE" \
    "$APP/LICENSE"

chmod +x \
    "$STAGING/documents/Custom Screensaver.sh" \
    "$APP/custom_ss_daemon.sh" \
    "$APP/toggle.sh" \
    "$APP/bin/screensaver_shield" \
    "$APP/bin/fbink_hf"

rm -f "$OUTPUT/$PACKAGE_NAME"

(
    cd "$STAGING"
    zip -r "$OUTPUT/$PACKAGE_NAME" \
        documents \
        extensions \
        screensavers
)

echo "Created:"
echo "$OUTPUT/$PACKAGE_NAME"