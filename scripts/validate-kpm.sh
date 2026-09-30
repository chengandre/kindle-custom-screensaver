#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 PACKAGE VERSION REPOSITORY_MANIFEST" >&2
    exit 1
fi

PACKAGE="$1"
VERSION="$2"
REPOSITORY_MANIFEST="$3"
EXPECTED_PACKAGE_NAME="custom-screensaver_${VERSION}_kindlehf.kpkg"

fail() {
    echo "KPM validation failed: $*" >&2
    exit 1
}

if [ ! -f "$PACKAGE" ]; then
    fail "package not found: $PACKAGE"
fi

if [ "$(basename -- "$PACKAGE")" != "$EXPECTED_PACKAGE_NAME" ]; then
    fail "package filename does not match build version $VERSION"
fi

if [ ! -f "$REPOSITORY_MANIFEST" ]; then
    fail "repository manifest not found: $REPOSITORY_MANIFEST"
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

ARCHIVE_LIST="$TEMP_DIR/archive.list"
PACKAGE_CONTENTS="$TEMP_DIR/package"
mkdir "$PACKAGE_CONTENTS"

# Listing and extracting independently catches unreadable or corrupt archives.
tar -tzf "$PACKAGE" > "$ARCHIVE_LIST" \
    || fail "archive cannot be listed: $PACKAGE"
tar -xzf "$PACKAGE" -C "$PACKAGE_CONTENTS" \
    || fail "archive cannot be extracted: $PACKAGE"

for path in \
    manifest.json \
    install.sh \
    uninstall.sh \
    launch.sh \
    lifecycle.sh \
    "scriptlets/Custom Screensaver.sh" \
    payload/runtime/custom_ss_daemon.sh \
    payload/runtime/toggle.sh \
    payload/runtime/blanket_renderers.sh \
    payload/runtime/cover_lookup.sh \
    payload/runtime/bin/screensaver_shield \
    payload/runtime/bin/cover_extract \
    payload/runtime/bin/fbink_hf \
    payload/runtime/build-metadata.txt \
    payload/runtime/LICENSE \
    payload/runtime/THIRD_PARTY_NOTICES.md \
    payload/runtime/licenses/FBInk/LICENSE \
    payload/runtime/licenses/FBInk/CREDITS
do
    grep -Fqx "$path" "$ARCHIVE_LIST" \
        || fail "archive is missing expected root-relative path: $path"
done

for path in \
    install.sh \
    uninstall.sh \
    launch.sh \
    "scriptlets/Custom Screensaver.sh" \
    payload/runtime/custom_ss_daemon.sh \
    payload/runtime/toggle.sh \
    payload/runtime/bin/screensaver_shield \
    payload/runtime/bin/fbink_hf
do
    if [ ! -x "$PACKAGE_CONTENTS/$path" ]; then
        fail "expected executable is not executable: $path"
    fi
done

MANIFEST="$PACKAGE_CONTENTS/manifest.json"
jq -e . "$MANIFEST" > /dev/null \
    || fail "manifest.json is not valid JSON"
jq -e '.manifest_version == 2' "$MANIFEST" > /dev/null \
    || fail "manifest_version must be 2"
jq -e '.id == "custom-screensaver"' "$MANIFEST" > /dev/null \
    || fail "manifest ID must be custom-screensaver"
jq -e --arg version "$VERSION" \
    '.version == ($version | split(".") | map(tonumber))' \
    "$MANIFEST" > /dev/null \
    || fail "manifest package version does not match build version $VERSION"
jq -e '(.supported_platforms | index("kindlehf")) != null' \
    "$MANIFEST" > /dev/null \
    || fail "manifest does not support kindlehf"

jq -e . "$REPOSITORY_MANIFEST" > /dev/null \
    || fail "repository manifest is not valid JSON"
jq -e '.manifest_version == 2' "$REPOSITORY_MANIFEST" > /dev/null \
    || fail "repository manifest_version must be 2"
jq -e --arg version "$VERSION" \
    '.packages["custom-screensaver"].artifacts[0].version
        == ($version | split(".") | map(tonumber))' \
    "$REPOSITORY_MANIFEST" > /dev/null \
    || fail "repository package version does not match build version $VERSION"
jq -e '(.packages["custom-screensaver"].artifacts[0].supported_platforms
        | index("kindlehf")) != null' \
    "$REPOSITORY_MANIFEST" > /dev/null \
    || fail "repository manifest does not support kindlehf"
jq -e \
    --arg url "https://github.com/chengandre/kindle-custom-screensaver/releases/download/v${VERSION}/${EXPECTED_PACKAGE_NAME}" \
    '.packages["custom-screensaver"].artifacts[0].url == $url' \
    "$REPOSITORY_MANIFEST" > /dev/null \
    || fail "repository package URL does not match build version $VERSION"

if grep -RInE '@[A-Z][A-Z0-9_]*@' "$PACKAGE_CONTENTS"; then
    fail "package contains unresolved template placeholders"
fi

if grep -nE '@[A-Z][A-Z0-9_]*@' "$REPOSITORY_MANIFEST"; then
    fail "repository manifest contains unresolved template placeholders"
fi

echo "Validated KPM package: $PACKAGE"
