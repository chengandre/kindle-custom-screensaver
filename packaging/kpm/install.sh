#!/bin/sh
set -eu

. ./lifecycle.sh

NEW_APP="/mnt/us/extensions/.custom-screensaver.new.$$"
OLD_APP="/mnt/us/extensions/.custom-screensaver.old.$$"
NEW_SCRIPTLET="/mnt/us/documents/.Custom Screensaver.sh.new.$$"
OLD_SCRIPTLET="/mnt/us/documents/.Custom Screensaver.sh.old.$$"
APP_BACKED_UP=0
APP_INSTALLED=0
SCRIPTLET_BACKED_UP=0
SCRIPTLET_INSTALLED=0
INSTALL_COMPLETE=0

rollback_install() {
    rm -rf "$NEW_APP"
    rm -f "$NEW_SCRIPTLET"

    if [ "$INSTALL_COMPLETE" -eq 0 ]; then
        if [ "$APP_INSTALLED" -eq 1 ]; then
            rm -rf "$APP"
        fi

        if [ "$APP_BACKED_UP" -eq 1 ] && [ -d "$OLD_APP" ]; then
            mv "$OLD_APP" "$APP"
        fi

        if [ "$SCRIPTLET_INSTALLED" -eq 1 ]; then
            rm -f "$SCRIPTLET"
        fi

        if [ "$SCRIPTLET_BACKED_UP" -eq 1 ] && [ -f "$OLD_SCRIPTLET" ]; then
            mv "$OLD_SCRIPTLET" "$SCRIPTLET"
        fi
    fi

    rm -rf "$OLD_APP"
    rm -f "$OLD_SCRIPTLET"
}

trap rollback_install EXIT
trap 'exit 1' HUP INT TERM

case "${1:-}" in
    ""|upgrade) ;;
    *)
        echo "Unknown install mode: $1" >&2
        exit 1
        ;;
esac

mkdir -p /mnt/us/extensions /mnt/us/documents "$SCREENSAVERS"
mkdir "$NEW_APP"
cp -R ./payload/runtime/. "$NEW_APP"
cp "./scriptlets/Custom Screensaver.sh" "$NEW_SCRIPTLET"

chmod +x \
    "$NEW_APP/custom_ss_daemon.sh" \
    "$NEW_APP/toggle.sh" \
    "$NEW_APP/bin/screensaver_shield" \
    "$NEW_APP/bin/cover_extract" \
    "$NEW_APP/bin/fbink_hf" \
    "$NEW_SCRIPTLET"

# KPM calls the old uninstall hook first during an upgrade, but stopping here
# as well keeps direct/retried installs safe before any runtime is replaced.
stop_custom_screensaver

if [ -d "$APP" ]; then
    mv "$APP" "$OLD_APP"
    APP_BACKED_UP=1
fi

if [ -f "$SCRIPTLET" ]; then
    mv "$SCRIPTLET" "$OLD_SCRIPTLET"
    SCRIPTLET_BACKED_UP=1
fi

mv "$NEW_APP" "$APP"
APP_INSTALLED=1
mv "$NEW_SCRIPTLET" "$SCRIPTLET"
SCRIPTLET_INSTALLED=1

INSTALL_COMPLETE=1
