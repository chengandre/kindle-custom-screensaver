#!/bin/sh
# Name: Toggle Custom Screensaver
# DontUseFBInk

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DAEMON="$BASE/custom_ss_daemon.sh"
FBINK="$BASE/bin/fbink_hf"
SS_DIR="/mnt/us/screensavers"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_renderers"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/launcher.log"

. "$BASE/blanket_renderers.sh"


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}


show_status() {
    if ! chmod +x "$FBINK" >>"$LOG" 2>&1 ||
        ! "$FBINK" -p -m -M -S 5 -w "$1" >>"$LOG" 2>&1
    then
        log "ERROR: could not display status message"
        return 0
    fi

    sleep 3

    if ! DISPLAY=:0 xrefresh >>"$LOG" 2>&1; then
        log "ERROR: could not repaint Kindle interface after status message"
    fi
}


daemon_is_running() {
    if [ ! -f "$PIDFILE" ]; then
        return 1
    fi

    PID="$(cat "$PIDFILE" 2>/dev/null)"

    if [ -z "$PID" ]; then
        return 1
    fi

    if ! kill -0 "$PID" 2>/dev/null; then
        return 1
    fi

    # Make sure the PID actually belongs to our daemon,
    # rather than some unrelated process that reused the PID.
    if [ -r "/proc/$PID/cmdline" ]; then
        tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null |
            grep -F "$DAEMON" >/dev/null 2>&1 ||
            return 1
    fi

    return 0
}


emergency_cleanup() {
    EMERGENCY_RESULT=0

    #
    # Kill a leftover shield, if there is one.
    #
    if [ -f "$SHIELD_PIDFILE" ]; then
        SPID="$(cat "$SHIELD_PIDFILE" 2>/dev/null)"

        if [ -n "$SPID" ]; then
            kill "$SPID" 2>/dev/null
        fi

        rm -f "$SHIELD_PIDFILE"
    fi

    #
    # If the daemon left behind its original-state record, restore the exact
    # renderer set that was active before startup.
    #
    if restore_original_renderers; then
        if [ -f "$STATEFILE" ]; then
            log "Emergency renderer restore complete"
        fi
    else
        log "ERROR: emergency renderer restore incomplete"
        EMERGENCY_RESULT=1
    fi

    rm -f \
        "$PIDFILE" \
        "$INDEXFILE" \
        "$FIFO"

    if [ "$EMERGENCY_RESULT" -eq 0 ]; then
        rm -f "$STATEFILE"
    fi

    DISPLAY=:0 xrefresh >>"$LOG" 2>&1

    return "$EMERGENCY_RESULT"
}


disable_custom_ss() {
    PID="$(cat "$PIDFILE" 2>/dev/null)"

    log "Disabling custom screensaver (PID $PID)"

    #
    # TERM triggers the daemon's cleanup trap.
    #
    kill "$PID" 2>/dev/null

    #
    # Give it up to 5 seconds to cleanly exit and restore Blanket.
    #
    COUNT=0

    while kill -0 "$PID" 2>/dev/null; do
        sleep 1
        COUNT=$((COUNT + 1))

        if [ "$COUNT" -ge 5 ]; then
            log "ERROR: daemon did not exit within 5 seconds"
            return 1
        fi
    done

    #
    # Normally the daemon has already cleaned everything.
    # This catches anything left behind.
    #
    if ! emergency_cleanup; then
        log "ERROR: custom screensaver disabled, but renderer restoration failed"
        return 1
    fi

    log "Custom screensaver DISABLED"
}


enable_custom_ss() {
    if [ ! -f "$DAEMON" ]; then
        log "ERROR: daemon missing: $DAEMON"
        show_status "Could not enable
custom screensaver.
See logs."
        exit 1
    fi

    #
    # Clean any stale files from an abnormal previous exit.
    #
    if ! emergency_cleanup; then
        log "ERROR: cannot enable while renderer restoration is incomplete"
        show_status "Could not enable
custom screensaver.
See logs."
        exit 1
    fi

    HAS_IMAGES=0
    for IMAGE in "$SS_DIR"/*.[pP][nN][gG] "$SS_DIR"/*.[jJ][pP][gG] "$SS_DIR"/*.[jJ][pP][eE][gG]; do
        if [ -f "$IMAGE" ]; then
            HAS_IMAGES=1
            break
        fi
    done

    if [ "$HAS_IMAGES" -eq 0 ]; then
        log "ERROR: no PNG or JPEG screensaver images"
        show_status "Add PNG or JPG images
to /screensavers/"
        exit 1
    fi

    chmod +x "$DAEMON"

    log "Enabling custom screensaver"

    sh "$DAEMON" >/dev/null 2>&1 &

    NEWPID=$!

    #
    # Give the daemon a moment to initialize.
    #
    sleep 1

    if [ -f "$PIDFILE" ]; then
        PID="$(cat "$PIDFILE" 2>/dev/null)"

        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            log "Custom screensaver ENABLED (PID $PID)"
            show_status "Custom screensaver
turned on"
            exit 0
        fi
    fi

    log "ERROR: daemon failed to start"

    kill "$NEWPID" 2>/dev/null
    emergency_cleanup
    show_status "Could not enable
custom screensaver.
See logs."

    exit 1
}


#
# -------------------------
# Command
# -------------------------
#

case "${1:-toggle}" in
    disable)
        if daemon_is_running; then
            disable_custom_ss
        else
            rm -f "$PIDFILE"

            if [ -f "$SHIELD_PIDFILE" ] || \
                [ -f "$STATEFILE" ] || \
                [ -f "$INDEXFILE" ] || \
                [ -p "$FIFO" ]
            then
                emergency_cleanup
            fi
        fi
        ;;

    toggle)
        if daemon_is_running; then
            if disable_custom_ss; then
                show_status "Custom screensaver
turned off"
            else
                show_status "Could not disable
custom screensaver.
See logs."
                exit 1
            fi
        else
            #
            # Remove a stale PID file if the recorded process
            # no longer exists.
            #
            rm -f "$PIDFILE"

            enable_custom_ss
        fi
        ;;

    *)
        echo "Usage: $0 [disable]" >&2
        exit 1
        ;;
esac
