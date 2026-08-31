#!/bin/sh

# Blanket renderer state management shared by the daemon and its emergency
# cleanup path. Callers provide STATEFILE, LOG, and log().

get_blanket_modules() {
    lipc-get-prop com.lab126.blanket load 2>>"$LOG"
}


blanket_has_module() {
    BR_MODULES="$1"
    BR_MODULE="$2"

    printf '%s\n' "$BR_MODULES" |
        tr '[:space:]' '\n' |
        grep -qx "$BR_MODULE"
}


log_blanket_modules() {
    BR_CONTEXT="$1"

    if BR_MODULES="$(get_blanket_modules)"; then
        log "Blanket modules $BR_CONTEXT: ${BR_MODULES:-(none)}"
    else
        log "ERROR: failed to read Blanket modules $BR_CONTEXT"
    fi
}


detect_renderers() {
    BR_MODULES="$1"
    BR_DETECTED=""

    if blanket_has_module "$BR_MODULES" screensaver; then
        BR_DETECTED="screensaver"
    fi

    if blanket_has_module "$BR_MODULES" ad_screensaver; then
        if [ -n "$BR_DETECTED" ]; then
            BR_DETECTED="$BR_DETECTED ad_screensaver"
        else
            BR_DETECTED="ad_screensaver"
        fi
    fi

    if [ -n "$BR_DETECTED" ]; then
        printf '%s\n' "$BR_DETECTED"
    else
        printf '%s\n' "none"
    fi
}


valid_renderer_state() {
    case "$1" in
        none|screensaver|ad_screensaver|"screensaver ad_screensaver")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


capture_renderer_state() {
    if ! BLANKET_MODULES="$(get_blanket_modules)"; then
        log "ERROR: failed to read Blanket modules at startup"
        return 1
    fi

    if [ -n "$BLANKET_MODULES" ]; then
        log "Blanket modules at startup: $BLANKET_MODULES"
    else
        log "Blanket modules at startup: (none)"
    fi

    ORIGINAL_RENDERERS="$(detect_renderers "$BLANKET_MODULES")"

    if ! printf '%s\n' "$ORIGINAL_RENDERERS" > "$STATEFILE"; then
        log "ERROR: failed to record original Blanket renderer state"
        return 1
    fi

    log "Detected renderer(s): $ORIGINAL_RENDERERS"

    if [ "$ORIGINAL_RENDERERS" = "screensaver ad_screensaver" ]; then
        log "WARNING: both stock renderers detected; both will be temporarily unloaded"
    fi
}


disable_original_renderers() {
    BR_RENDERERS="$(cat "$STATEFILE" 2>/dev/null)"

    if ! valid_renderer_state "$BR_RENDERERS"; then
        log "ERROR: invalid saved Blanket renderer state: $BR_RENDERERS"
        return 1
    fi

    if [ "$BR_RENDERERS" = "none" ]; then
        log "Renderer unload result: no renderer change"
        return 0
    fi

    BR_RESULT=0

    for BR_RENDERER in $BR_RENDERERS; do
        if lipc-set-prop com.lab126.blanket unload "$BR_RENDERER" >>"$LOG" 2>&1; then
            log "Renderer unload succeeded: $BR_RENDERER"
        else
            log "ERROR: renderer unload failed: $BR_RENDERER"
            BR_RESULT=1
        fi
    done

    log_blanket_modules "after unload"

    return "$BR_RESULT"
}


restore_original_renderers() {
    if [ ! -f "$STATEFILE" ]; then
        return 0
    fi

    BR_RENDERERS="$(cat "$STATEFILE" 2>/dev/null)"

    if ! valid_renderer_state "$BR_RENDERERS"; then
        log "ERROR: invalid saved Blanket renderer state: $BR_RENDERERS"
        return 1
    fi

    if [ "$BR_RENDERERS" = "none" ]; then
        log "Renderer restore result: no renderer change"
        return 0
    fi

    if ! BR_CURRENT_MODULES="$(get_blanket_modules)"; then
        log "ERROR: failed to read Blanket modules during restore"
        return 1
    fi

    BR_RESULT=0

    for BR_RENDERER in $BR_RENDERERS; do
        if blanket_has_module "$BR_CURRENT_MODULES" "$BR_RENDERER"; then
            log "Renderer already loaded: $BR_RENDERER"
        elif lipc-set-prop com.lab126.blanket load "$BR_RENDERER" >>"$LOG" 2>&1; then
            log "Renderer restore succeeded: $BR_RENDERER"
            BR_CURRENT_MODULES="$BR_CURRENT_MODULES $BR_RENDERER"
        else
            log "ERROR: renderer restore failed: $BR_RENDERER"
            BR_RESULT=1
        fi
    done

    log_blanket_modules "after restore"

    return "$BR_RESULT"
}
