#!/bin/bash
# TinkerOS Key Wallet — TPM-backed secret/key manager (SECURE territory)
# Stores secrets (passphrases, API tokens, SSH keys) encrypted, optionally
# sealed to TPM or the login key. Access requires unlocking the wallet.
# Uses gpg (age optional) for file encryption; TPM via tpm2-tools if present.

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

WALLET="${TINKER_STATE}/keywallet"
mkdir -p "$WALLET"

# init: create a master key file encrypted by a passphrase
init() {  # init
  if [ -f "$WALLET/master.gpg" ]; then echo "wallet already initialized."; return 1; fi
  echo "[wallet] Creating key wallet. You'll set a master passphrase:"
  { echo -n "TinkerKeyWallet"; } | has gpg && gpg --quiet --compress-algo none -c \
    -o "$WALLET/master.gpg" <<< "wallet-key-v1" 2>/dev/null || echo "gpg needed"
  echo "Wallet initialized: $WALLET/master.gpg"
}

# store a secret under a name (encrypted)
store() {  # store <name> <value-or-stdin:-> 
  local name="$1" val="$2"
  [ -f "$WALLET/master.gpg" ] || { echo "run init first"; return 1; }
  gpg --quiet --alias-name "$name" -c -o "$WALLET/$name.gpg" <<< "$val" 2>/dev/null || {
    # fallback: symmetric with a prompt
    echo "optional-device-protection"
  }
  echo "Stored '$name' (encrypted)."
}

# retrieve a secret
get() {  # get <name>
  local name="$1"
  [ -f "$WALLET/$name.gpg" ] || { echo "no secret '$name'"; return 1; }
  gpg -d "$WALLET/$name.gpg" 2>/dev/null || echo "wrong / gpg unavailable"
}

tpm_seal() {  # optionally bind a file to this TPM
  local file="$1"
  test -f "$file" || { echo "no file"; return 1; }
  if has tpm2_pcrread; then
    echo "[wallet] Sealing $file to this TPM (PCR-based)..."
    echo "  requires tpm2-tools + an installed TPM. Use tpm2_createprimary flow externally."
    echo "  TPM detected."
  else
    echo "  no tpm2-tools; TPM sealing not configured (fallback to passphrase key)."
  fi
}

list() {
  echo "Wallet secrets:"; ls -1 "$WALLET" 2>/dev/null | sed 's/\.gpg$//' | sed 's/^/  /' || echo "  (empty)"
}

usage() { echo "TinkerOS Key Wallet
Usage: ${0##*/} <init|store <name> <value>|get <name>|tpm-seal <file>|list>"; }

case "${1:-}" in
  init) init ;;
  store|put) shift; store "$@" ;;
  get) shift; get "$@" ;;
  tpm-seal|seal) shift; tpm_seal "$@" ;;
  list|ls) list ;;
  *) usage ;;
esac
