#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

VERSION="${VERSION:-0.0.1}"
TARGET="${TARGET:-kindlehf}"
PACKAGE_NAME="custom-screensaver-${VERSION}-${TARGET}.zip"

DIST="$ROOT/dist"
STAGING="$ROOT/build/package-zip"
OUTPUT="$ROOT/release"

APP="$STAGING/extensions/custom-screensaver"

rm -rf "$STAGING"

mkdir -p \
    "$STAGING/documents" \
    "$STAGING/screensavers" \
    "$OUTPUT"

cp \
    "$ROOT/packaging/common/documents/Custom Screensaver.sh" \
    "$STAGING/documents/Custom Screensaver.sh"

cp \
    "$ROOT/packaging/zip/screensavers/README.txt" \
    "$STAGING/screensavers/README.txt"

"$ROOT/scripts/stage-runtime.sh" "$APP"

chmod +x \
    "$STAGING/documents/Custom Screensaver.sh"

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
