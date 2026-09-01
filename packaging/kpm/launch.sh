#!/bin/sh

APP="/mnt/us/extensions/custom-screensaver"

if [ ! -f "$APP/toggle.sh" ]; then
    exit 1
fi

exec sh "$APP/toggle.sh"
