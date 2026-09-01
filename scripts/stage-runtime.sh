#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DESTINATION" >&2
    exit 1
fi

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DESTINATION="$1"
DIST="$ROOT/dist"

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

mkdir -p \
    "$DESTINATION/bin" \
    "$DESTINATION/licenses/FBInk"

cp "$ROOT/src/scripts/custom_ss_daemon.sh" "$DESTINATION/custom_ss_daemon.sh"
cp "$ROOT/src/scripts/toggle.sh" "$DESTINATION/toggle.sh"
cp "$ROOT/src/scripts/blanket_renderers.sh" "$DESTINATION/blanket_renderers.sh"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$DESTINATION/THIRD_PARTY_NOTICES.md"
cp "$ROOT/licenses/FBInk/LICENSE" "$DESTINATION/licenses/FBInk/LICENSE"
cp "$ROOT/licenses/FBInk/CREDITS" "$DESTINATION/licenses/FBInk/CREDITS"
cp "$DIST/screensaver_shield" "$DESTINATION/bin/screensaver_shield"
cp "$DIST/fbink_hf" "$DESTINATION/bin/fbink_hf"
cp "$DIST/build-metadata.txt" "$DESTINATION/build-metadata.txt"
cp "$ROOT/LICENSE" "$DESTINATION/LICENSE"

chmod +x \
    "$DESTINATION/custom_ss_daemon.sh" \
    "$DESTINATION/toggle.sh" \
    "$DESTINATION/bin/screensaver_shield" \
    "$DESTINATION/bin/fbink_hf"
