#!/bin/bash
# TinkerOS Hack Ways — large offensive techniques library (HACK territory)
# A structured library of many distinct authorized-testing techniques,
# each with: a helper command, what it does, and a consent flag.
#
# This is education + authorized-engagement tooling. Use ONLY on systems you
# own or are explicitly permitted to test. Techniques flagged [CONSENT]
# absolutely require written authorization.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Each entry: name|tool|difficulty|consent|description
WAYS=(
  "recon-active|nmap -sV -sC|easy|[CONSENT]|service/version enumeration of an authorized target"
  "recon-passive|whois + dig + shodan cli|easy|OK|passive intel, no traffic to target"
  "os-fingerprint|nmap -O|medium|[CONSENT]|OS detection (needs specific open ports)"
  "subdomain-enum|gobuster dns / ffuf|medium|OK|enumerate subdomains of owned domain"
  "dir-bruteforce|gobuster dir -w rockyou|medium|[CONSENT]|directory/file discovery"
  "api-discovery|ffuf -w api-words|medium|OK|find hidden API endpoints"
  "web-spider|whatweb / wpscan|easy|OK|web fingerprint (CMS, frameworks)"
  "cache-poisoning|curl -H X-Forwarded-Host|hard|[CONSENT]|web cache poisoning analysis"
  "ssrf-test|curl -v -H Host:169.254.169.254|hard|[CONSENT]|server-side request forgery"
  "sqli-test|sqlmap -u URL --batch|medium|[CONSENT]|SQL injection (batch)"
  "xss-check|eval payload in browser (manual)|medium|[CONSENT]|cross-site scripting"
  "idor-test|enumerate object ids manually|medium|[CONSENT]|insecure direct object reference"
  "auth-bruteforce|hydra -l admin -P list ssh|medium|[CONSENT]|auth testing (rate-aware)"
  "session-hijack|manual cookie diff|hard|OK|session fixation analysis (own app)"
  "phishing-encode|social-engineering toolkit (set)|hard|[CONSENT]|authorized SE test"
  "wifi-deauth|aireplay-ng --deauth|medium|[CONSENT]|deauth test on OWN/authorized AP"
  "wifi-crack|aircrack-ng -w list cap|hard|[CONSENT]|WPA handshake crack own AP"
  "bluetooth-scan|btmgmt discover|medium|OK|discover BT devices (passive)"
  "ble-analysis|hcitool lescan + gatttool|hard|OK|BLE scanning own/permitted devices"
  "rf-sdr|rtl_fm capture|medium|OK|raw RF capture licensed bands only"
  "usb-hid-inject|ducky script on test bench|hard|[CONSENT]|HID injection (own test bench)"
  "forensics-img|dd if=/dev/sdX of=img|medium|OK|forensics image of authorized disk"
  "memory-dump|volatility -f mem|hard|OK|memory forensics on captured image"
  "file-carve|foremost -i image|medium|OK|file carving from image"
  "stego-detect|steghide extract test|medium|OK|steganography detection on own files"
  "crypto-test|hashcat -m 0 crack|medium|OK|crack own/test hashes"
  "log-analysis|grep/awk on auth.log|easy|OK|analyze own logs for anomalies"
  "reverse-basic|strings + objdump|medium|OK|static analysis basics"
  "packer-id|die (detect it easy)|easy|OK|identify packing/obfuscation"
  "debugger|gdb breakpoints manual|hard|OK|dynamic analysis with gdb"
  "intrusion-sim|metasploit framework lite|hard|[CONSENT]|simulate intrusion (authorized only)"
  "lateral-move|ssh-key reuse tests|hard|[CONSENT]|lateral movement in lab"
  "persistence-test|systemd unit test lab|hard|[CONSENT]|persistence mechanisms in own lab"
  "exfil-sim|encoded http exfil lab|hard|[CONSENT]|data exfil simulation (lab)"
  "rabbit-hole|bash one-liner redirection|easy|OK|shell redirection tricks"
  "firmware-peek|binwalk -e|medium|OK|firmware extraction of own device images"
)

show_way() {
  local name="$1"
  for w in "${WAYS[@]}"; do
    local n tool diff cons desc
    n="${w%%|*}"; rest="${w#*|}"; tool="${rest%%|*}"; rest="${rest#*|}"
    diff="${rest%%|*}"; rest="${rest#*|}"; cons="${rest%%|*}"; desc="${rest#*|}"
    if [ "$n" = "$name" ]; then
      echo "Name:     $n"
      echo "Tool/cmd: $tool"
      echo "Difficulty: $diff"
      echo "Consent:  $cons"
      echo "What:     $desc"
      return 0
    fi
  done
  echo "Unknown technique: $name"
  return 1
}

list_ways() {
  local i=1
  echo "TinkerOS HACK WAYS library ($((${#WAYS[@]})) techniques)"
  echo "--------------------------------------------------------"
  for w in "${WAYS[@]}"; do
    local n tool diff cons desc
    n="${w%%|*}"; rest="${w#*|}"; tool="${rest%%|*}"; rest="${rest#*|}"
    diff="${rest%%|*}"; rest="${rest#*|}"
    cons="${rest%%|*}"; desc="${rest#*|}"
    printf '  %-26s %-5s %s\n' "$n" "$diff" "$cons"
  done
}

list_by_difficulty() {
  local want="$1"
  echo "Techniques at difficulty $want:"
  for w in "${WAYS[@]}"; do
    local n diff cons; n="${w%%|*}"; rest="${w#*|}"; rest="${rest#*}"; rest="${rest#*}"
    diff="${rest%%|*}"; rest="${rest#*|}"
    cons="${rest%%|*}"
    [ "$diff" = "$want" ] && echo "  $n ($cons)"
  done
}

# consent-gated launcher: refuse any [CONSENT] way without a passphrase file
run_way() {
  local name="$1"; shift
  for w in "${WAYS[@]}"; do
    local n diff cons
    n="${w%%|*}"; rest="${w#*|}"; rest="${rest#*|}"; rest="${rest#*|}"
    diff="${rest%%|*}"; rest="${rest#*|}"; cons="${rest%%|*}"
    if [ "$n" = "$name" ]; then
      if [[ "$cons" == *CONSENT* ]]; then
        echo "This technique [CONSENT] requires authorization."
        echo "Create $HOME/.config/tinker/authorization.txt mentioning this scope to proceed."
        echo "It is your legal responsibility to obtain authorization."
        [ -f "$HOME/.config/tinker/authorization.txt" ] || return 1
      fi
      echo "Running technique: $n -> ${w#*|}"
      echo "(invoke the tool with your target; shown bare for safety)"
      return 0
    fi
  done
  show_way "$name"
}

count_ways() { echo "${#WAYS[@]}"; }

case "${1:-}" in
  list|ls) list_ways ;;
  count) count_ways ;;
  show|info) shift; show_way "$@" ;;
  easy|medium|hard) list_by_difficulty "$1" ;;
  run) shift; run_way "$@" ;;
  *) echo "TinkerOS Hack Ways library
Usage: ${0##*/} <list|count|show <name>|easy|medium|hard|run <name>>
A broad library of authorized-testing techniques with consent flags.
AUTHORIZED USE ONLY. You are responsible for legality." ;;
esac
