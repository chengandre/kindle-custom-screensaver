#!/bin/sh

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BIN="$BASE/bin"
SS_DIR="/mnt/us/screensavers"

FBINK="$BIN/fbink_hf"
SHIELD="$BIN/screensaver_shield"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_renderers"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/custom_ss.log"

. "$BASE/blanket_renderers.sh"

SLEEP_PID=""
WAKE_PID=""
CLEANED=0


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
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

    if restore_original_renderers; then
        rm -f "$STATEFILE"
    else
        log "ERROR: renderer restore incomplete; preserving $STATEFILE for emergency cleanup"
    fi

    rm -f "$PIDFILE"
    rm -f "$INDEXFILE"

    DISPLAY=:0 xrefresh >>"$LOG" 2>&1

    log "Cleanup complete"
}


list_screensaver_images() {
    for IMAGE in "$SS_DIR"/*; do
        [ -f "$IMAGE" ] || continue

        case "$IMAGE" in
            *.[pP][nN][gG]|*.[jJ][pP][gG]|*.[jJ][pP][eE][gG])
                printf '%s\n' "$IMAGE"
                ;;
        esac
    done
}


draw_screensaver() {
    IMAGES="$(list_screensaver_images)"

    if [ -z "$IMAGES" ]; then
        log "ERROR: no PNG or JPEG files"
        return 1
    fi

    COUNT="$(echo "$IMAGES" | wc -l)"

    LAST="$(cat "$INDEXFILE" 2>/dev/null)"

    if [ -z "$LAST" ]; then
        LAST="-1"
    fi

    NEXT=$(( (LAST + 1) % COUNT ))
    ATTEMPTS=0

    while [ "$ATTEMPTS" -lt "$COUNT" ]; do
        IMG="$(echo "$IMAGES" | sed -n "$((NEXT + 1))p")"

        log "Drawing: $IMG"

        "$FBINK" \
            -i "$IMG" -g w=-1,h=-1 \
            -f >>"$LOG" 2>&1

        RESULT=$?

        if [ "$RESULT" -eq 0 ]; then
            echo "$NEXT" > "$INDEXFILE"
            return 0
        fi

        log "ERROR: skipping $IMG; FBInk returned $RESULT"
        NEXT=$(( (NEXT + 1) % COUNT ))
        ATTEMPTS=$((ATTEMPTS + 1))
    done

    log "ERROR: all $COUNT screensaver images failed to render"
    return 1
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

if [ -z "$(list_screensaver_images)" ]; then
    log "ERROR: no PNG or JPEG screensaver images"
    exit 1
fi

chmod +x "$FBINK" "$SHIELD"

echo $$ > "$PIDFILE"


#
# Remember the original renderer state before modifying Blanket.
#

if ! capture_renderer_state; then
    rm -f "$PIDFILE" "$STATEFILE"
    exit 1
fi


#
# Clean up every resource acquired from this point onward.
#

trap 'cleanup; exit 0' HUP INT TERM
trap 'cleanup' EXIT


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
    outOfScreenSaver,goingToPasswdDlg >&3 2>>"$LOG" &
WAKE_PID=$!

#
# Disable the Amazon renderer(s) that were active at startup.
#

if ! disable_original_renderers; then
    log "ERROR: renderer startup changes failed; shutting daemon down"
    exit 1
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


        # The managed screensaver shield stays behind the stock PIN dialog.
        # Unmapping it here would expose and repaint the book or menu.
        *goingToPasswdDlg*)

            log "PIN dialog requested; keeping screensaver behind dialog"

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
