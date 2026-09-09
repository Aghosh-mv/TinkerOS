#!/bin/bash
# TinkerOS kernel GameMode hook — bridges Feral GameMode activation to the
# in-kernel gamemode governor boost (/proc/tinker/gamemode).
#
# Called from gamemode.ini [custom] start/end.  Feral gamemoded passes the
# requesting game's PID as the first argument; when absent we fall back to
# the newest live app process on the machine (started this session).
#
# Usage:
#   tinker-gamemode-hook.sh on    [game pid]
#   tinker-gamemode-hook.sh off
#   tinker-gamemode-hook.sh status
#
# Requires the TinkerOS kernel (CONFIG_TINKER_GAMEMODE=y). If the proc node
# is missing the hook degrades to a logged notice and never fails the caller.

PROC_GAMEMODE="${TINKER_PROC_GAMEMODE:-/proc/tinker/gamemode}"
LOG="/tmp/tinker-gamemode-hook.log"

hook_log() { echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null || true; }

# Newest live app process: any running process (not kernel threads, not our
# own parents) with tty=0 and a start time after the boot origin.
newest_app_pid() {
    local now pid start best=0 bestpid=0 comm
    now=$(grep -m1 btime /proc/stat | awk '{print $2}')
    for d in /proc/[0-9]*; do
        pid=${d#/proc/}
        [ -r "$d/stat" ] || continue
        start=$(awk '{print $22}' "$d/stat" 2>/dev/null) || continue
        [ -z "$start" ] && continue
        comm=$(cat "$d/comm" 2>/dev/null)
        # skip kernel threads (have no cmdline) and ourself
        { [ -r "$d/cmdline" ] && [ -s "$d/cmdline" ]; } || continue
        if [ "$start" -gt "$best" ] 2>/dev/null; then best=$start; bestpid=$pid; fi
    done
    echo "$bestpid"
}

do_on() {
    local pid="${1:-}"
    if [ -z "$pid" ] || ! echo "$pid" | grep -qE '^[0-9]+$'; then
        pid=$(newest_app_pid)
        hook_log "on: no explicit pid, selected $pid"
    fi
    if [ -n "$pid" ] && [ -w "$PROC_GAMEMODE" ]; then
        # shellcheck disable=SC2154
        if echo "on $pid" > "$PROC_GAMEMODE" 2>>"$LOG"; then
            hook_log "kernel gamemode ON for tgid $pid"
        else
            hook_log "kernel gamemode ON FAILED (tgid $pid)"
        fi
    else
        hook_log "PROC_GAMEMODE not writable — kernel gamemode unavailable"
    fi
}

do_off() {
    if [ -w "$PROC_GAMEMODE" ]; then
        if echo "off" > "$PROC_GAMEMODE" 2>>"$LOG"; then
            hook_log "kernel gamemode OFF"
        fi
    else
        hook_log "PROC_GAMEMODE not writable — kernel gamemode unavailable"
    fi
}

do_status() {
    if [ -r "$PROC_GAMEMODE" ]; then
        cat "$PROC_GAMEMODE"
        echo
    else
        echo "kernel gamemode proc node not present (non-TinkerOS kernel?)"
    fi
}

case "${1:-}" in
    on)     shift; do_on "${1:-}" ;;
    off)    do_off ;;
    status) do_status ;;
    *) echo "usage: $0 on [pid] | off | status" ;;
esac