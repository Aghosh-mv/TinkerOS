#!/bin/bash
# TinkerOS World Arsenal Installer
# Populates each isolated mode-world with its mode-scoped toolset:
#   HACK   -> offensive (black-hat) + defensive (white-hat) hacking toolset
#   GAME   -> NVIDIA drivers, GameMode, Proton/Wine, game launchers, overlays
#   NORMAL -> the user's daily-driver apps
#
# Tools are installed into the world's own apps dir, NOT system-wide, so the
# worlds remain isolated. This is a meta-installer: it detects what's
# available (apt/pip/fetch) and stages tool definitions into each world.
#
# NOTE ON ETHICS/LEGALITY: "Offensive" tools are staged as *capability
# definitions + permission notes* for authorized security testing on systems
# you own or have written permission to test. Use responsibly and lawfully.

set -euo pipefail

TERR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORLD_HACK="$TERR_ROOT/hack"
WORLD_GAME="$TERR_ROOT/game"
WORLD_NORMAL="$TERR_ROOT/normal"

mkdir -p "$WORLD_HACK/apps/bin" "$WORLD_GAME/apps/bin" "$WORLD_NORMAL/apps/bin"

has() { command -v "$1" >/dev/null 2>&1; }

# ---- HACK WORLD: offensive + defensive toolset ------------------------------
HACK_OFFENSIVE=(
  "nmap             network scanner (port/host discovery)"
  "ncat|netcat      raw TCP/UDP relaying"
  "masscan          very fast port scanner"
  "hydra            online password guessing (auth testing)"
  "john             John the Ripper offline password cracker"
  "hashcat          GPU/CPU hash cracking"
  "aircrack-ng      Wi-Fi audit (must have consent to test own/authorized nets)"
  "recon-ng         web reconnaissance framework"
  "sqlmap           SQL injection testing (authorized targets only)"
  "metasploit       exploit development framework"
  "burpsuite        web proxy for web-app pentesting"
  "wireshark        packet capture + analysis"
  "tcpdump          CLI packet capture"
  "ettercap         MITM testing framework"
  "bettercap        modern MITM / sniffing toolkit"
  "beef             browser exploit framework"
  "yara             malware pattern matching"
  "volatility       memory forensics"
)
HACK_DEFENSIVE=(
  "lynis            security auditing"
  "chkrootkit       rootkit detector"
  "rkhunter         rootkit hunter"
  "clamav           antivirus scanner"
  "rkhunter         rootkit hunter"
  "openscap         SCAP compliance scanning"
  "fail2ban         intrusion prevention (log-based)"
  "tripwire         file integrity monitoring"
  "aide             advanced intrusion detection env"
  "osquery          OS instrumentation/querying"
  "snort            network IDS/IPS"
  "suricata         high-performance IDS/IPS"
)

# ---- GAME WORLD: performance gaming toolset ---------------------------------
GAME_TOOLS=(
  "nvidia-driver-560 NVIDIA proprietary driver (hardware acceleration)"
  "libnvidia-gl-1    NVIDIA GL runtime"
  "gamemode         Feral GameMode (CPU governor + IO priority boost)"
  "mangohud         performance overlay (FPS/thermals)"
  "lutris           game manager (Wine/Proton)"
  "proton-ge         GloriousEggroll Proton builds"
  "wine              Windows compatibility layer"
  "wine64            x86_64 Wine"
  "steam             Steam client + Proton"
  "winehq-stable      stable Wine packages"
  "mesa-vulkan-drivers Vulkan for AMD/Intel GPUs"
  "libvulkan1        Vulkan loader"
  "vulkan-tools      vulkaninfo etc."
  "lib32-mesa        ico 32-bit Mesa (Unity/UE games)"
  "openal            cross-platform 3D audio"
  "game-mode-dbus    GameMode DBus integration"
  "cpu-x             CPU info"
  "coolero           system fan control gui"
)

# ---- NORMAL WORLD: daily driver ---------------------------------------------
NORMAL_TOOLS=(
  "firefox   web browser"
  "libreoffice  office suite"
  "vlc        media player"
  "gimp       image editor"
  "code       VS Code editor"
  "git        version control"
  "gcc        C compiler"
  "python3    Python"
  "nodejs     Node.js"
  "htop       system monitor"
  "openssh-client ssh client"
  "curl,wget  download tools"
)

stage_definition() {  # stage_definition <world_dir> <name:desc...>
  local world="$1"; shift
  local name desc i
  for entry in "$@"; do
    IFS=: read -r name desc <<< "$entry"
    IFS=' ' read -r name _ <<< "$name"
    cat > "$world/apps/$name.meta" <<EOF
# TinkerOS world app definition
name=$name
desc=$desc
world=$(basename "$world")
staged=$(date -Iseconds)
EOF
  done
}

# Classify whether a named tool is currently present (for reporting)
report_toolset() {
  local world="$1"; shift
  echo "== $(basename "$world") world toolset =="
  for entry in "$@"; do
    local name
    IFS=: read -r name _ <<< "$entry"
    IFS=' ' read -r name _ <<< "$name"
    printf '  %-18s %s\n' "$name" "$(has "${name%%,*}" && echo "[present]" || echo "[to install]")"
  done
}

# Detect preamble binaries that might be split multi-word
_prep() { :; }

case "${1:-}" in
  hack|offensive)
    stage_definition "$WORLD_HACK" "${HACK_OFFENSIVE[@]}" "${HACK_DEFENSIVE[@]}"
    echo "Staged $(( ${#HACK_OFFENSIVE[@]} + ${#HACK_DEFENSIVE[@]} )) hack-tool definitions into hack world."
    ;;
  game)
    stage_definition "$WORLD_GAME" "${GAME_TOOLS[@]}"
    echo "Staged ${#GAME_TOOLS[@]} game-tool definitions (NVIDIA/GameMode/Proton/Wine/overlays)."
    ;;
  normal)
    stage_definition "$WORLD_NORMAL" "${NORMAL_TOOLS[@]}"
    echo "Staged ${#NORMAL_TOOLS[@]} normal/daily-driver definitions."
    ;;
  report-hack)  report_toolset "$WORLD_HACK" "${HACK_OFFENSIVE[@]}" "${HACK_DEFENSIVE[@]}" ;;
  report-game)  report_toolset "$WORLD_GAME" "${GAME_TOOLS[@]}" ;;
  report-normal) report_toolset "$WORLD_NORMAL" "${NORMAL_TOOLS[@]}" ;;
  all)
    stage_definition "$WORLD_HACK" "${HACK_OFFENSIVE[@]}" "${HACK_DEFENSIVE[@]}"
    stage_definition "$WORLD_GAME" "${GAME_TOOLS[@]}"
    stage_definition "$WORLD_NORMAL" "${NORMAL_TOOLS[@]}"
    echo "Staged all three world tool-sets."
    ;;
  *) echo "TinkerOS World Arsenal Installer
Usage: ${0##*/} <hack|game|normal|all|report-hack|report-game|report-normal>
Populates each isolated mode-world with its mode-scoped toolset.
Tools are staged as metadata + detection; run the matching package manager
(apt/pip/fetch) to actually install. HACK tools are for authorized testing only." ;;
esac
