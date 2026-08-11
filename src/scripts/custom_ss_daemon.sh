#!/bin/sh

BASE="/mnt/us/extensions/custom-screensaver"
BIN="$BASE/bin"
SS_DIR="$BASE/screensavers"

FBINK="$BIN/fbink_hf"
SHIELD="$BIN/screensaver_shield"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_screensaver"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/custom_ss.log"

SLEEP_PID=""
WAKE_PID=""
CLEANED=0


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}


has_screensaver_module() {
    lipc-get-prop com.lab126.blanket load 2>/dev/null |
        tr ' ' '\n' |
        grep -qx "screensaver"
}


shield_down() {
    if [ -f "$SHIELD_PIDFILE" ]; then
        SPID="$(cat "$SHIELD_PIDFILE" 2>/dev/null)"

        if [ -n "$SPID" ]; then
            kill "$SPID" 2>/dev/null
            wait "$SPID" 2>/dev/null
        fi

        rm -f "$SHIELD_PIDFILE"
        log "Shield stopped"
    fi
}


shield_up() {
    shield_down

    DISPLAY=:0 "$SHIELD" >>"$LOG" 2>&1 &
    SPID=$!

    echo "$SPID" > "$SHIELD_PIDFILE"

    log "Shield started (PID $SPID)"
}


restore_screensaver() {
    if [ -f "$STATEFILE" ]; then
        RESTORE="$(cat "$STATEFILE" 2>/dev/null)"

        if [ "$RESTORE" = "1" ]; then
            if ! has_screensaver_module; then
                lipc-set-prop \
                    com.lab126.blanket \
                    load screensaver >>"$LOG" 2>&1

                log "Stock screensaver module restored"
            else
                log "Stock screensaver already loaded"
            fi
        fi
    fi
}


cleanup() {
    if [ "$CLEANED" -eq 1 ]; then
        return
    fi

    CLEANED=1

    log "Cleaning up"

    if [ -n "$SLEEP_PID" ]; then
        kill "$SLEEP_PID" 2>/dev/null
    fi

    if [ -n "$WAKE_PID" ]; then
        kill "$WAKE_PID" 2>/dev/null
    fi

    shield_down

    exec 3>&- 2>/dev/null
    exec 3<&- 2>/dev/null

    rm -f "$FIFO"

    restore_screensaver

    rm -f "$PIDFILE"
    rm -f "$STATEFILE"
    rm -f "$INDEXFILE"

    DISPLAY=:0 xrefresh >>"$LOG" 2>&1

    log "Cleanup complete"
}


draw_screensaver() {
    IMAGES="$(ls "$SS_DIR"/*.png 2>/dev/null)"

    if [ -z "$IMAGES" ]; then
        log "ERROR: no *.png files"
        return 1
    fi

    COUNT="$(echo "$IMAGES" | wc -l)"

    LAST="$(cat "$INDEXFILE" 2>/dev/null)"

    if [ -z "$LAST" ]; then
        LAST="-1"
    fi

    NEXT=$(( (LAST + 1) % COUNT ))

    echo "$NEXT" > "$INDEXFILE"

    IMG="$(echo "$IMAGES" | sed -n "$((NEXT + 1))p")"

    log "Drawing: $IMG"

    "$FBINK" \
        -g file="$IMG",w=-1,h=-1 \
        -f >>"$LOG" 2>&1

    RESULT=$?

    if [ "$RESULT" -ne 0 ]; then
        log "ERROR: FBInk returned $RESULT"
        return "$RESULT"
    fi

    return 0
}


#
# ----- startup validation -----
#

echo "" >> "$LOG"
log "=== Custom screensaver starting ==="

if [ ! -f /lib/ld-linux-armhf.so.3 ]; then
    log "ERROR: hard-float loader not found"
    exit 1
fi

if [ ! -f "$FBINK" ]; then
    log "ERROR: fbink_hf missing"
    exit 1
fi

if [ ! -f "$SHIELD" ]; then
    log "ERROR: ss_shield missing"
    exit 1
fi

if ! ls "$SS_DIR"/*.png >/dev/null 2>&1; then
    log "ERROR: no screensaver images"
    exit 1
fi

chmod +x "$FBINK" "$SHIELD"

echo $$ > "$PIDFILE"


#
# Remember the ORIGINAL screensaver state.
#

if has_screensaver_module; then
    echo "1" > "$STATEFILE"
    log "Original state: stock screensaver loaded"
else
    echo "0" > "$STATEFILE"
    log "Original state: stock screensaver not loaded"
fi


#
# Event listeners
#

rm -f "$FIFO"

mkfifo "$FIFO" || {
    log "ERROR: couldn't create FIFO"
    exit 1
}

exec 3<>"$FIFO"

lipc-wait-event \
    -m com.lab126.powerd \
    goingToScreenSaver >&3 2>>"$LOG" &
SLEEP_PID=$!

lipc-wait-event \
    -m com.lab126.powerd \
    outOfScreenSaver >&3 2>>"$LOG" &
WAKE_PID=$!


#
# Install cleanup before touching Blanket.
#

trap 'cleanup; exit 0' HUP INT TERM
trap 'cleanup' EXIT


#
# Disable ONLY Amazon's regular screensaver renderer.
#

if has_screensaver_module; then
    lipc-set-prop \
        com.lab126.blanket \
        unload screensaver >>"$LOG" 2>&1

    log "Stock screensaver module unloaded"
fi

log "READY"


#
# ----- main loop -----
#

while read -r LINE <&3; do

    log "EVENT: $LINE"

    case "$LINE" in

        *goingToScreenSaver*)

            shield_up

            if draw_screensaver; then
                log "Custom screensaver drawn"
            else
                log "Drawing failed - shutting daemon down"
                exit 1
            fi

            ;;


        *outOfScreenSaver*)

            shield_down

            "$FBINK" \
                -k -f -W GC16 >>"$LOG" 2>&1

            DISPLAY=:0 \
                xrefresh >>"$LOG" 2>&1

            log "Wake refresh complete"

            ;;

    esac
done