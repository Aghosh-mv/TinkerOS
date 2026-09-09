#!/bin/bash
# iso-artifacts — generates the sha256 + sizes manifest for a finished TinkerOS
# ISO, for the SourceForge release notes. Purely local; writes <iso>.sha256 next
# to the ISO (never commits the ISO itself).
#
# Usage: os/iso-artifacts.sh [path/to/TinkerOS-*.iso]

set -euo pipefail

ISO="${1:-}"
[ -z "$ISO" ] && ISO=$(ls -1 /home/tinkerspace/linux-kernel/TinkerOS-*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "no ISO found: $0 [path]"; exit 1; }

echo "Artifacts manifest for $ISO"
echo "  size   : $(stat -c%s "$ISO") bytes ($(numfmt --to=iec "$(stat -c%s "$ISO")"))"
sha256sum "$ISO"
echo "  sha256 : $(sha256sum "$ISO" | awk '{print $1}')"
sha256sum "$ISO" | awk -v n="$(basename "$ISO")" '{print $1"  "n}' > "$ISO.sha256"
echo "  wrote  : $ISO.sha256"
echo
echo "Bake details (from the build log stages):"
for f in /tmp/iso-final.log /tmp/iso-relog.log /tmp/iso-build.log; do
  [ -f "$f" ] && echo "    $f  $(wc -l < "$f") lines"
done