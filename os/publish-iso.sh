#!/bin/bash
# TinkerOS ISO Publisher — uploads the finished ISO to SourceForge FRS.
#
# Policy (DISTRIBUTION_STRATEGY.md): the large ISO is NEVER pushed to git.
# It lives only on SourceForge's mirrors and is linked from the GitHub README.
#
# Upload channel: SourceForge File Release System over SSH (sftp).
#   host: frs.sourceforge.net
#   path: /home/frs/project/tinkeros/
#
# Usage:
#   SF_USER=<your-sf-account> ./os/publish-iso.sh [path/to/file.iso]
#
# Authentication uses the configured SSH identity (~/.ssh/id_ed25519 by
# default, or SF_SSH_KEY). The same public key must be registered on the
# SourceForge account (Account settings -> SSH Keys).

set -euo pipefail

HOST="${SF_HOST:-frs.sourceforge.net}"
USER="${SF_USER:?set SF_USER to your SourceForge account name (or pass as 2nd arg)}"
KEY="${SF_SSH_KEY:-$HOME/.ssh/id_ed25519}"
PROJECT="${SF_PROJECT:-tinkeros}"
REMOTE_PATH="/home/frs/project/$PROJECT"

ISO="${1:-$(ls -1 TinkerOS-*.iso 2>/dev/null | head -1)}"
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  echo "no ISO found; provide a path: $0 /path/to/TinkerOS-*.iso" >&2
  exit 1
fi

size=$(stat -c%s "$ISO")
echo "Publishing ${ISO} ($(numfmt --to=iec "$size"))  ->  ${USER}@${HOST}:${REMOTE_PATH}/"
echo "  identity: ${KEY}"

echo "[1/3] verifying SSH identity against SourceForge..."
if ! ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=15 "${USER}@${HOST}" 'echo AUTH_OK' >/tmp/sf-auth.check 2>&1; then
  echo "  SSH handshake failed:"; sed 's/^/    /' /tmp/sf-auth.check
  echo "  Register this public key on your SourceForge account:"
  cat "$KEY.pub"
  exit 1
fi
cat /tmp/sf-auth.check

echo "[2/3] listing current remote files..."
sftp -i "$KEY" -o BatchMode=yes "${USER}@${HOST}" <<EOF
ls -la $REMOTE_PATH
EOF

echo "[3/3] uploading..."
sftp -i "$KEY" -o BatchMode=yes "${USER}@${HOST}" <<EOF
put "$ISO" $REMOTE_PATH/
EOF

echo
echo "Done. Link it from the GitHub README:"
echo "  https://sourceforge.net/projects/$PROJECT/files/"
echo "  (exact file: https://sourceforge.net/projects/$PROJECT/files/$(basename "$ISO")/download)"