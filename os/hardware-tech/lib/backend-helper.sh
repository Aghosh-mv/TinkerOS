#!/bin/bash
# TinkerOS backend-helper - shared C backend discovery + consent integration
# Sources: os/hardware-tech/lib/hardware-consent.sh
# Provides: hardware_backend_probe, hardware_backend_try, hardware_write_gate
HBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"    # os/hardware-tech
HBE_BIN="$HBE_DIR/backend/bin"

# Load the consent gate if present
if [[ -f "$HBE_DIR/lib/hardware-consent.sh" ]]; then
  source "$HBE_DIR/lib/hardware-consent.sh"
fi

# ── Discover compiled C backend ────────────────────────────────────────
backend_available() {
  local tool="$1"
  [[ -x "$HBE_BIN/$tool" ]]
}

# ── Full path to a built backend binary (or empty) ─────────────────────
backend_bin_path() {
  local tool="$1"
  if backend_available "$tool"; then
    printf '%s' "$HBE_BIN/$tool"
  fi
}

# ── Pair: prefer C backend, fall back to a shell/python fallback cmd ───
# Usage: backend_prefer <tool> <fallback_cmd...>
# Runs the C backend; if unavailable, runs the fallback command.
backend_prefer() {
  local tool="$1"; shift
  if backend_available "$tool"; then
    "$HBE_BIN/$tool" "$@"
  else
    return 127
  fi
}

# ── Run a C backend command, returning nonzero if unavailable/build-skipped
backend_run() {
  local tool="$1"; shift
  if ! backend_available "$tool"; then
    return 127   # binary not built
  fi
  "$HBE_BIN/$tool" "$@"
}

# ── Probes the tool and prints capability (for dashboards) ─────────────
backend_probe() {
  local tool="$1"; shift
  if backend_available "$tool"; then
    echo "[C-backend:$tool] available"
    backend_run "$tool" probe 2>/dev/null
  else
    echo "[C-backend:$tool] not built (run: make -C $HBE_DIR/backend)"
  fi
}

# ── Build the C backends if a compiler exists ──────────────────────────
backend_build() {
  if command -v gcc >/dev/null 2>&1 && [[ -f "$HBE_DIR/backend/Makefile" ]]; then
    (cd "$HBE_DIR/backend" && make >/dev/null 2>&1)
    return $?
  fi
  return 1
}

# ── Consent-gated hardware write ───────────────────────────────────────
# Usage: hardware_write_gate <feature> <--yes|prompt>
#   returns 0 if consented, echoes the feature to require consent.
#   Non-hardware (read/probe) commands should NOT call this.
hardware_write_gate() {
  local feature="$1"
  local noninter="$2"
  # consent feature name maps to the tool; default to the feature string
  hardware_consent "$feature" "$noninter"
  return $?
}

# ── Auto-consent helper (for `--yes` / non-interactive daemons) ────────
# Records consent silently ONLY if the feature is already approved in db;
# otherwise this is a no-op so reads still work without writing.
