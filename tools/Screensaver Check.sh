#!/bin/sh
# Name: Screensaver Check
# DontUseFBInk
#
# One-off device survey for the cover-mode fork. Copy into the Kindle's
# documents/ folder, tap it in the Library, then within 2 minutes:
#   open a book, wait ~10 s, press the power button to sleep, wake it,
#   wait ~10 s, go back to Home, wait ~10 s.
# The report is written to screensaver-check.txt in the Kindle's root.

OUT="/mnt/us/screensaver-check.txt"
DURATION=120

# Return immediately so the Library isn't blocked; survey in background.
if [ "$1" != "run" ]; then
    sh "$0" run >/dev/null 2>&1 &
    exit 0
fi

section() {
    echo ""
    echo "=== $1"
}

{
    echo "Screensaver Check started $(date)"

    section "system"
    uname -a
    cat /etc/prettyversion.txt 2>/dev/null
    ls -l /lib/ld-linux*.so* 2>&1

    section "tools"
    for tool in sqlite3 lipc-get-prop lipc-wait-event lipc-probe od xrefresh; do
        printf '%s: ' "$tool"
        which "$tool" 2>/dev/null || echo "MISSING"
    done

    section "blanket modules"
    lipc-get-prop com.lab126.blanket load 2>&1

    section "book formats in documents/"
    ls /mnt/us/documents 2>&1 | sed -n 's/.*\.//p' | sort | uniq -c

    section "appmgrd properties"
    lipc-probe -v com.lab126.appmgrd 2>&1 | head -40

    section "live log (changes only)"
} > "$OUT" 2>&1

# Record sleep/wake events in the background.
lipc-wait-event -m com.lab126.powerd goingToScreenSaver,outOfScreenSaver 2>&1 |
    while read -r EVENT; do
        echo "$(date '+%H:%M:%S') POWER EVENT: $EVENT" >> "$OUT"
    done &
EVENT_PID=$!

LAST_STATE=""
ELAPSED=0

while [ "$ELAPSED" -lt "$DURATION" ]; do
    APP="$(lipc-get-prop com.lab126.appmgrd activeApp 2>&1)"

    BOOK=""
    if which sqlite3 >/dev/null 2>&1; then
        BOOK="$(sqlite3 /var/local/cc.db \
            "SELECT p_cdeType, p_location FROM Entries WHERE p_type='Entry:Item' ORDER BY p_lastAccess DESC LIMIT 1;" 2>&1)"
    fi

    STATE="app=$APP | lastbook=$BOOK"

    if [ "$STATE" != "$LAST_STATE" ]; then
        echo "$(date '+%H:%M:%S') $STATE" >> "$OUT"
        LAST_STATE="$STATE"
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

kill "$EVENT_PID" 2>/dev/null
killall lipc-wait-event 2>/dev/null

{
    section "recently opened books"
    if which sqlite3 >/dev/null 2>&1; then
        sqlite3 /var/local/cc.db \
            "SELECT p_cdeKey, p_cdeType, p_location FROM Entries WHERE p_type='Entry:Item' ORDER BY p_lastAccess DESC LIMIT 5;" 2>&1
    fi

    echo ""
    echo "FINISHED $(date)"
} >> "$OUT" 2>&1
