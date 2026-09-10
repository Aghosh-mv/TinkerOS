#!/bin/bash
# os/release.sh — one-command TinkerOS release
#
# Reads the current version from README.md, bumps it, rebuilds the ISO,
# uploads to SourceForge, and git-tags the release.
#
# Usage:
#   os/release.sh            # auto-increment minor (1.2 → 1.3)
#   os/release.sh patch      # 1.2.0 → 1.2.1
#   os/release.sh major      # 1.x → 2.0
#   os/release.sh 2.5.0      # explicit version

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
README="$REPO/README.md"
BUILD="$REPO/os/build-distro.sh"
SF_USER="aghoshpratheesh"
SF_HOST="frs.sourceforge.net"
KEY="${SF_SSH_KEY:-$HOME/.ssh/id_ed25519}"

# --- read current version from README download link ---
CURRENT=$(grep -oP 'TinkerOS-v\K[0-9]+\.[0-9]+' "$README" | head -1)
[ -z "$CURRENT" ] && { echo "ERROR: cannot read current version from README"; exit 1; }
CUR_MAJOR=$(echo "$CURRENT" | cut -d. -f1)
CUR_MINOR=$(echo "$CURRENT" | cut -d. -f2)
CUR_PATCH="${CUR_PATCH:-0}"
echo "Current version: ${CUR_MAJOR}.${CUR_MINOR}"

# --- compute new version ---
bump() {
  local arg="${1:-}"
  case "$arg" in
    "")
      # auto-increment minor
      NEW_MAJOR="$CUR_MAJOR"
      NEW_MINOR=$((CUR_MINOR + 1))
      NEW_PATCH=0
      ;;
    patch)
      NEW_MAJOR="$CUR_MAJOR"
      NEW_MINOR="$CUR_MINOR"
      NEW_PATCH=$((CUR_PATCH + 1))
      ;;
    major)
      NEW_MAJOR=$((CUR_MAJOR + 1))
      NEW_MINOR=0
      NEW_PATCH=0
      ;;
    *)
      # explicit version like 2.5.0 or 2.5
      NEW_MAJOR=$(echo "$arg" | cut -d. -f1)
      NEW_MINOR=$(echo "$arg" | cut -d. -f2)
      NEW_PATCH=$(echo "$arg" | cut -d. -f3)
      [ -z "$NEW_PATCH" ] && NEW_PATCH=0
      ;;
  esac
}

bump "${1:-}"
NEW_VER="${NEW_MAJOR}.${NEW_MINOR}"
NEW_VER_FULL="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
ISO_NAME="TinkerOS-v${NEW_VER}.iso"
echo "New version: ${NEW_VER_FULL} → ${ISO_NAME}"
echo ""

# --- step 1: selftest gate ---
echo "[1/7] running selftest..."
bash "$REPO/os/territories/vibe-address/vibe-address.sh selftest" || {
  echo "ABORT: selftest failed"
  exit 1
}
echo ""

# --- step 2: update version strings ---
echo "[2/7] updating version strings..."

# build-distro.sh OUT path
sed -i "s|TinkerOS-v[0-9]*\.[0-9]*\.iso|${ISO_NAME}|g" "$BUILD"

# stage_branding os-release VERSION_ID
sed -i "s|VERSION_ID=\"[0-9]*\.[0-9]*\"|VERSION_ID=\"${NEW_VER}\"|g" "$BUILD"
sed -i "s|VERSION=\"[0-9]*\.[0-9]* |VERSION=\"${NEW_VER} |g" "$BUILD"
sed -i "s|TinkerOS [0-9]*\.[0-9]* (jammy)|TinkerOS ${NEW_VER} (jammy)|g" "$BUILD"

# README download link
sed -i "s|TinkerOS-v[0-9]*\.[0-9]*\.iso|${ISO_NAME}|g" "$README"

# commit the version bump
cd "$REPO"
git add os/build-distro.sh README.md os/docs/RELEASE-*.md 2>/dev/null || true
git commit -q -m "release: bump to v${NEW_VER_FULL}" || true
echo ""

# --- step 3: rebuild ISO ---
echo "[3/7] rebuilding ISO (this takes ~15 min)..."
bash "$BUILD" rebuild
echo ""

# --- step 4: checksum ---
echo "[4/7] generating SHA256..."
ISO_PATH="$REPO/$ISO_NAME"
[ -f "$ISO_PATH" ] || ISO_PATH=$(ls -1 "$REPO"/TinkerOS-v*.iso 2>/dev/null | head -1)
[ -f "$ISO_PATH" ] || { echo "ERROR: ISO not found after build"; exit 1; }
# rename if needed
if [ "$(basename "$ISO_PATH")" != "$ISO_NAME" ]; then
  mv "$ISO_PATH" "$REPO/$ISO_NAME"
  ISO_PATH="$REPO/$ISO_NAME"
fi
sha256sum "$ISO_PATH" | awk '{print $1"  "FILENAME}' FILENAME="$ISO_NAME" > "${ISO_PATH}.sha256"
SHA=$(awk '{print $1}' "${ISO_PATH}.sha256")
echo "  SHA256: $SHA"
echo ""

# --- step 5: update README with SHA + link ---
echo "[5/7] updating README with SHA256..."
sed -i "s|^\`[a-f0-9]\{64\}\`|${SHA}|" "$README"
# also update the SHA line if it exists
if grep -q 'SHA256' "$README"; then
  sed -i "/SHA256/c\| **SHA256** | \`${SHA}\` |" "$README"
fi
git add README.md
git commit -q -m "release: v${NEW_VER_FULL} ISO SHA256 ${SHA:0:12}..." || true
echo ""

# --- step 6: upload to SourceForge ---
echo "[6/7] uploading to SourceForge..."
sftp -o BatchMode=yes -o ConnectTimeout=15 -i "$KEY" "${SF_USER}@${SF_HOST}" <<EOF
mkdir /home/frs/project/tinkeros/v${NEW_VER}
cd /home/frs/project/tinkeros/v${NEW_VER}
put $ISO_PATH
put ${ISO_PATH}.sha256
ls -la
EOF
echo ""

# --- step 7: git tag ---
echo "[7/7] tagging v${NEW_VER_FULL}..."
git tag -a "v${NEW_VER_FULL}" -m "Release v${NEW_VER_FULL}" 2>/dev/null || true
git push origin "v${NEW_VER_FULL}" --quiet 2>/dev/null || true
git push origin master --quiet
echo ""

# --- done ---
echo "========================================="
echo "  TinkerOS v${NEW_VER_FULL} SHIPPED"
echo "========================================="
echo ""
echo "  ISO: https://sourceforge.net/projects/tinkeros/files/v${NEW_VER}/${ISO_NAME}/download"
echo "  SHA: ${SHA}"
echo "  Tag: v${NEW_VER_FULL}"
echo ""
