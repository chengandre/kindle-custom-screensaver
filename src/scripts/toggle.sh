#!/bin/sh
# Name: Toggle Custom Screensaver
# DontUseFBInk

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DAEMON="$BASE/custom_ss_daemon.sh"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_screensaver"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/launcher.log"


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}


has_screensaver_module() {
    lipc-get-prop com.lab126.blanket load 2>/dev/null |
        tr ' ' '\n' |
        grep -qx "screensaver"
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
    # If the daemon left behind its original-state record,
    # restore the stock screensaver if necessary.
    #
    if [ -f "$STATEFILE" ]; then
        RESTORE="$(cat "$STATEFILE" 2>/dev/null)"

        if [ "$RESTORE" = "1" ]; then
            if ! has_screensaver_module; then
                lipc-set-prop \
                    com.lab126.blanket \
                    load screensaver >>"$LOG" 2>&1

                log "Emergency restore: stock screensaver loaded"
            fi
        fi
    fi

    rm -f \
        "$PIDFILE" \
        "$STATEFILE" \
        "$INDEXFILE" \
        "$FIFO"

    DISPLAY=:0 xrefresh >>"$LOG" 2>&1
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
            log "Daemon did not exit within 5 seconds"
            break
        fi
    done

    #
    # Normally the daemon has already cleaned everything.
    # This catches anything left behind.
    #
    emergency_cleanup

    log "Custom screensaver DISABLED"
}


enable_custom_ss() {
    if [ ! -f "$DAEMON" ]; then
        log "ERROR: daemon missing: $DAEMON"
        exit 1
    fi

    #
    # Clean any stale files from an abnormal previous exit.
    #
    emergency_cleanup

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
            exit 0
        fi
    fi

    log "ERROR: daemon failed to start"

    kill "$NEWPID" 2>/dev/null
    emergency_cleanup

    exit 1
}


#
# -------------------------
# Toggle
# -------------------------
#

if daemon_is_running; then
    disable_custom_ss
else
    #
    # Remove a stale PID file if the recorded process
    # no longer exists.
    #
    rm -f "$PIDFILE"

    enable_custom_ss
fi

exit 0