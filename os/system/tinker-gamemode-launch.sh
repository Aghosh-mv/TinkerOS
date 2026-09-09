#!/bin/bash
# tinker-gamemode — launch an app with TinkerOS performance mode.
#
# Two-step boost:
#   1. Feral GameMode (gamemoderun) — userspace governor/GPU/graphics tuning.
#   2. TinkerOS in-kernel gamemode   — schedutil puts a P-state headroom step on
#      the boosted task while it runs (/proc/tinker/gamemode + tinker_task_boosted()).
#
# Usage:
#   tinker-gamemode <command...>
#   tinker-gamemode --status
#
# The kernel boost follows the app's PID, so it lifts exactly that process;
# when the app exits the boost is cleared and the OS returns to its normal,
# battery-friendly schedule.  Degrades gracefully when the TinkerOS kernel or
# Feral GameMode is absent.

set -u

HOOK="${TINKER_HOOK:-/opt/tinkeros/os/system/tinker-gamemode-hook.sh}"

usage() {
  echo "usage: tinker-gamemode <command...>   (or --status)"
}

run_app() {
  local cmd=("$@")
  local pid rc
  command -v gamemoderun >/dev/null 2>&1 || {
    echo "tinker-gamemode: gamemoderun not found (-)"
  }

  # launch through Feral GameMode while grabbing the real child PID
  gamemoderun "${cmd[@]}" &
  pid=$!
  if [ -x "$HOOK" ]; then
    "$HOOK" on "$pid"   # kernel schedutil headroom scoped to this app
  fi

  wait "$pid"
  rc=$?

  if [ -x "$HOOK" ]; then
    "$HOOK" off
  fi
  return "$rc"
}

case "${1:-}" in
  ""|-h|--help) usage; exit 0 ;;
  --status)
    if [ -x "$HOOK" ]; then "$HOOK" status; else echo "hook missing"; fi
    command -v gamemoderun >/dev/null 2>&1 && echo "gamemoderun: present" || echo "gamemoderun: absent"
    ;;
  *) run_app "$@" ;;
esac