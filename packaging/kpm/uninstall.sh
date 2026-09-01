#!/bin/sh
set -e

. ./lifecycle.sh

stop_custom_screensaver

if [ "${1:-}" = "upgrade" ]; then
    exit 0
fi

rm -rf "$APP"
rm -f "$SCRIPTLET"

# /mnt/us/screensavers is user data and must be preserved.
exit 0