#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DESTINATION" >&2
    exit 1
fi

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DESTINATION="$1"
DIST="$ROOT/dist"

# kindlehf builds produce fbink_hf; kindlepw2 builds produce fbink.
if [ -f "$DIST/fbink_hf" ]; then
    FBINK_NAME="fbink_hf"
else
    FBINK_NAME="fbink"
fi

for file in \
    "$DIST/screensaver_shield" \
    "$DIST/cover_extract" \
    "$DIST/$FBINK_NAME" \
    "$DIST/build-metadata.txt" \
    "$ROOT/LICENSE"
do
    if [ ! -f "$file" ]; then
        echo "Missing required file: $file" >&2
        exit 1
    fi
done

mkdir -p \
    "$DESTINATION/bin" \
    "$DESTINATION/licenses/FBInk"

cp "$ROOT/src/scripts/custom_ss_daemon.sh" "$DESTINATION/custom_ss_daemon.sh"
cp "$ROOT/src/scripts/toggle.sh" "$DESTINATION/toggle.sh"
cp "$ROOT/src/scripts/blanket_renderers.sh" "$DESTINATION/blanket_renderers.sh"
cp "$ROOT/src/scripts/cover_lookup.sh" "$DESTINATION/cover_lookup.sh"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$DESTINATION/THIRD_PARTY_NOTICES.md"
cp "$ROOT/licenses/FBInk/LICENSE" "$DESTINATION/licenses/FBInk/LICENSE"
cp "$ROOT/licenses/FBInk/CREDITS" "$DESTINATION/licenses/FBInk/CREDITS"
cp "$DIST/screensaver_shield" "$DESTINATION/bin/screensaver_shield"
cp "$DIST/cover_extract" "$DESTINATION/bin/cover_extract"
cp "$DIST/$FBINK_NAME" "$DESTINATION/bin/$FBINK_NAME"
cp "$DIST/build-metadata.txt" "$DESTINATION/build-metadata.txt"
cp "$ROOT/LICENSE" "$DESTINATION/LICENSE"

chmod +x \
    "$DESTINATION/custom_ss_daemon.sh" \
    "$DESTINATION/toggle.sh" \
    "$DESTINATION/bin/screensaver_shield" \
    "$DESTINATION/bin/cover_extract" \
    "$DESTINATION/bin/$FBINK_NAME"
