#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

DIST="$ROOT/dist"
STAGING="$ROOT/build/package-zip"
OUTPUT="$ROOT/release"

APP="$STAGING/extensions/custom-screensaver"

for file in \
    "$DIST/screensaver_shield" \
    "$DIST/fbink_hf"
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
    "$DIST/screensaver_shield" \
    "$APP/bin/screensaver_shield"

cp \
    "$DIST/fbink_hf" \
    "$APP/bin/fbink_hf"

chmod +x \
    "$STAGING/documents/Custom Screensaver.sh" \
    "$APP/custom_ss_daemon.sh" \
    "$APP/toggle.sh" \
    "$APP/bin/screensaver_shield" \
    "$APP/bin/fbink_hf"

rm -f "$OUTPUT/custom-screensaver-kindlehf.zip"

(
    cd "$STAGING"
    zip -r "$OUTPUT/custom-screensaver-kindlehf.zip" \
        documents \
        extensions \
        screensavers
)

echo "Created:"
echo "$OUTPUT/custom-screensaver-kindlehf.zip"