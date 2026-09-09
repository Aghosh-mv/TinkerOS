#!/bin/bash
# tinker-dust — TinkerOS fan dust-dislodger CLI (kernel: /proc/tinker/dust_dislodger).
#
# SAFETY model (per user directive): the fan is NEVER shaken until its
# specifications are CALCULATED first:
#
#   1. calibrate <max_rpm>   — declare the fan's rated ceiling (from the
#                              label / spec sheet). This builds the whole
#                              safety envelope: RPM-per-PWM slope, stall
#                              floor + margin, resonance-safe pulse ceiling,
#                              trough-safe amplitude cap.
#   2. rpm <measured>        — optional refinement with a real tach read
#                              while the machine is running.
#   3. run                   — only allowed once state == CALCULATED
#                              (kernel refuses otherwise); pulse/amplitude
#                              are auto-clamped to the envelope.
#
# The kernel module refuses `run` until step 1 (or 1+2) has happened.

set -u

PROC="${TINKER_PROC_DUST:-/proc/tinker/dust_dislodger}"

cmd() { echo "$@" > "$PROC" 2>/dev/null || { echo "tinker-dust: write to $PROC failed (TinkerOS kernel needed)" >&2; exit 1; }; }

usage() {
  cat <<'EOF'
usage: tinker-dust status | calibrate <max_rpm> | rpm <measured_rpm> | run | on | off | pulse <hz>
  status            show the calculated fan envelope + gate state
  calibrate <rpm>   DECLARE the fan's rated max rpm (required before run)
  rpm <rpm>         refine the envelope with a live measured tach read
  run               shake to dislodge dust (only if spec CALCULATED)
  on | off          consent toggle for the module's shaker
  pulse <hz>        manual oscillation frequency (auto-clamped on run)
EOF
}

case "${1:-}" in
  ""|-h|--help) usage ;;
  status)   cat "$PROC" 2>/dev/null || echo "no $PROC (TinkerOS kernel required)"; echo ;;
  calibrate) [ -n "${2:-}" ] || { echo "tinker-dust: calibrate needs <max_rpm>"; exit 2; }; cmd calibrate "$2"; echo "calibrated to ${2} rpm rated ceiling" ;;
  rpm)      [ -n "${2:-}" ] || { echo "tinker-dust: rpm needs <measured_rpm>"; exit 2; }; cmd rpm "$2"; echo "envelope refined from measured ${2} rpm" ;;
  run)      if [ "$(cat "$PROC" 2>/dev/null)" ] && grep -qi "CALCULATED" "$PROC" 2>/dev/null; then cmd run; echo "dust shake requested (spec-gated)"; else echo "tinker-dust: fan spec NOT calculated yet — calibrate <max_rpm> first"; exit 3; fi ;;
  on|off)   cmd "$1"; echo "consent: $1" ;;
  pulse)    [ -n "${2:-}" ] || { echo "tinker-dust: pulse needs <hz>"; exit 2; }; cmd pulse "$2"; echo "pulse set to ${2} Hz" ;;
  *) echo "tinker-dust: unknown command '$1'"; usage; exit 2 ;;
esac