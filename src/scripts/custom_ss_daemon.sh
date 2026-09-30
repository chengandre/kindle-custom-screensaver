#!/bin/sh

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BIN="$BASE/bin"
SS_DIR="/mnt/us/screensavers"

FBINK="$BIN/fbink_hf"
SHIELD="$BIN/screensaver_shield"

# kindlepw2 (soft-float) builds ship bin/fbink instead of bin/fbink_hf.
if [ ! -f "$FBINK" ]; then
    FBINK="$BIN/fbink"
fi

TARGET="$(sed -n 's/^target=//p' "$BASE/build-metadata.txt" 2>/dev/null)"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_renderers"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/custom_ss.log"

. "$BASE/blanket_renderers.sh"
. "$BASE/cover_lookup.sh"

SLEEP_PID=""
WAKE_PID=""
CLEANED=0


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}


#
# Ask X clients to repaint the whole screen (what xrefresh does). Firmware
# 5.12 ships without xrefresh, so the shield binary provides the same thing.
#
screen_refresh() {
    DISPLAY=:0 "$SHIELD" --refresh >>"$LOG" 2>&1
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
    rm -f "$COVER_CACHE_PREFIX"*

    screen_refresh

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

    #
    # Pick a random image, avoiding an immediate repeat when there is
    # more than one. BusyBox ash may lack $RANDOM, so read /dev/urandom.
    #
    RAND="$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')"

    if [ "$COUNT" -gt 1 ] && [ -n "$LAST" ]; then
        NEXT=$(( (LAST + 1 + RAND % (COUNT - 1)) % COUNT ))
    else
        NEXT=$(( RAND % COUNT ))
    fi

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


draw_cover() {
    log "Drawing cover: $1"

    "$FBINK" \
        -c -f -W GC16 \
        -g file="$1",w=-2,h=-2,halign=CENTER,valign=CENTER,dither >>"$LOG" 2>&1

    RESULT=$?

    if [ "$RESULT" -ne 0 ]; then
        log "ERROR: FBInk returned $RESULT for cover"
        return "$RESULT"
    fi

    return 0
}


#
# ----- startup validation -----
#

echo "" >> "$LOG"
log "=== Custom screensaver starting ==="

if [ "$TARGET" = "kindlepw2" ]; then
    LOADER="/lib/ld-linux.so.3"
else
    LOADER="/lib/ld-linux-armhf.so.3"
fi

if [ ! -f "$LOADER" ]; then
    log "ERROR: loader $LOADER not found (build target: ${TARGET:-kindlehf})"
    exit 1
fi

if [ ! -f "$FBINK" ]; then
    log "ERROR: fbink missing"
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

chmod +x "$FBINK" "$SHIELD" "$COVER_EXTRACT" 2>/dev/null

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
    outOfScreenSaver >&3 2>>"$LOG" &
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

            if cover_mode_enabled && in_book &&
                COVER="$(current_cover_path)" &&
                draw_cover "$COVER"
            then
                log "Book cover drawn"
            elif draw_screensaver; then
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

            screen_refresh

            log "Wake refresh complete"

            ;;

    esac
done
