#!/bin/sh
set -eu

. ./lifecycle.sh

case "${1:-}" in
    upgrade)
        stop_custom_screensaver
        exit 0
        ;;
    "") ;;
    *)
        echo "Unknown uninstall mode: $1" >&2
        exit 1
        ;;
esac

stop_custom_screensaver

rm -rf "$APP"

# Preserve a Scriptlet that the user or another installer has changed.
if [ -f "$SCRIPTLET" ]; then
    INSTALLED_HASH="$(md5sum "$SCRIPTLET" | awk '{print $1}')"
    PACKAGE_HASH="$(md5sum "./scriptlets/Custom Screensaver.sh" | awk '{print $1}')"

    if [ "$INSTALLED_HASH" = "$PACKAGE_HASH" ]; then
        rm -f "$SCRIPTLET"
    fi
fi

# /mnt/us/screensavers is user data and is intentionally never removed.
exit 0
