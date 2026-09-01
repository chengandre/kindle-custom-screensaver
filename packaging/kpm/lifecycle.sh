#!/bin/sh

APP="/mnt/us/extensions/custom-screensaver"
SCRIPTLET="/mnt/us/documents/Custom Screensaver.sh"
SCREENSAVERS="/mnt/us/screensavers"

stop_custom_screensaver() {
    if [ -f "$APP/toggle.sh" ]; then
        sh "$APP/toggle.sh" disable
        return
    fi

    if [ -f /tmp/custom_ss_daemon.pid ] || \
        [ -f /tmp/custom_ss_shield.pid ] || \
        [ -f /tmp/custom_ss_restore_renderers ] || \
        [ -p /tmp/custom_ss_events.fifo ]
    then
        echo "Cannot safely stop custom screensaver: $APP/toggle.sh is missing" >&2
        return 1
    fi
}
