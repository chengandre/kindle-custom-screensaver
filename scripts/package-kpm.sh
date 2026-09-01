#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.1}"
PACKAGE_NAME="custom-screensaver_${VERSION}_kindlehf.kpkg"
STAGING="$ROOT/build/package-kpm"
OUTPUT="$ROOT/release"
RUNTIME="$STAGING/payload/runtime"

OLD_IFS="$IFS"
IFS=.
set -- $VERSION
IFS="$OLD_IFS"

if [ "$#" -ne 3 ]; then
    echo "KPM versions must have exactly three numeric components: $VERSION" >&2
    exit 1
fi

for component in "$@"; do
    case "$component" in
        ""|*[!0-9]*)
            echo "KPM versions must have exactly three numeric components: $VERSION" >&2
            exit 1
            ;;
    esac
done

VERSION_MAJOR="$1"
VERSION_MINOR="$2"
VERSION_PATCH="$3"

rm -rf "$STAGING"
mkdir -p "$STAGING/scriptlets" "$RUNTIME" "$OUTPUT"

"$ROOT/scripts/stage-runtime.sh" "$RUNTIME"

cp "$ROOT/packaging/kpm/install.sh" "$STAGING/install.sh"
cp "$ROOT/packaging/kpm/uninstall.sh" "$STAGING/uninstall.sh"
cp "$ROOT/packaging/kpm/launch.sh" "$STAGING/launch.sh"
cp "$ROOT/packaging/kpm/lifecycle.sh" "$STAGING/lifecycle.sh"
cp "$ROOT/packaging/common/documents/Custom Screensaver.sh" \
    "$STAGING/scriptlets/Custom Screensaver.sh"

chmod +x \
    "$STAGING/install.sh" \
    "$STAGING/uninstall.sh" \
    "$STAGING/launch.sh" \
    "$STAGING/scriptlets/Custom Screensaver.sh"

sed \
    -e "s/@VERSION_MAJOR@/$VERSION_MAJOR/g" \
    -e "s/@VERSION_MINOR@/$VERSION_MINOR/g" \
    -e "s/@VERSION_PATCH@/$VERSION_PATCH/g" \
    "$ROOT/packaging/kpm/manifest.json.in" > "$STAGING/manifest.json"

sed \
    -e "s/@VERSION@/$VERSION/g" \
    -e "s/@VERSION_MAJOR@/$VERSION_MAJOR/g" \
    -e "s/@VERSION_MINOR@/$VERSION_MINOR/g" \
    -e "s/@VERSION_PATCH@/$VERSION_PATCH/g" \
    "$ROOT/packaging/kpm/repository.json.in" > "$OUTPUT/kpm-repository.json"

rm -f "$OUTPUT/$PACKAGE_NAME"

(
    cd "$STAGING"
    tar -czf "$OUTPUT/$PACKAGE_NAME" \
        manifest.json \
        install.sh \
        uninstall.sh \
        launch.sh \
        lifecycle.sh \
        payload \
        scriptlets
)

echo "Created:"
echo "$OUTPUT/$PACKAGE_NAME"
echo "$OUTPUT/kpm-repository.json"
