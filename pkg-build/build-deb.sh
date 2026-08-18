#!/bin/bash
# TinkerOS DEB Package Builder

set -e

ROOT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
OS_DIR="$ROOT_DIR/os"
BUILD_DIR="/tmp/tinker-deb-build"
OUTPUT_DIR="$HOME/Desktop/TinkerOS-Packages"
VERSION="7.2.0"
ARCH="amd64"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Package definitions
declare -A PACKAGES=(
    ["tinkeros-desktop"]="tinkeros-desktop: XFCE desktop with TinkerOS branding"
    ["tinkeros-system"]="tinkeros-system: Core system utilities and configuration"
    ["tinkeros-apps"]="tinkeros-apps: Essential applications bundle"
    ["tinkeros-security"]="tinkeros-security: Security hardening and tools"
    ["tinkeros-gaming"]="tinkeros-gaming: Gaming optimizations and tools"
    ["tinkeros-dev"]="tinkeros-dev: Development environment"
    ["tinkeros-enterprise"]="tinkeros-enterprise: Enterprise features"
    ["tinkeros-ai"]="tinkeros-ai: Local AI assistant (TinkerAI)"
    ["tinkeros-cowork"]="tinkeros-cowork: Native cowork AI"
    ["tinkeros-control-center"]="tinkeros-control-center: Unified control center"
)

# Function to create package
create_package() {
    local pkg_name="$1"
    local pkg_desc="$2"
    local pkg_dir="$BUILD_DIR/$pkg_name"
    
    echo "Building $pkg_name..."
    
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/lib/tinker"
    mkdir -p "$pkg_dir/usr/bin"
    mkdir -p "$pkg_dir/usr/share/applications"
    mkdir -p "$pkg_dir/usr/share/icons/hicolor/48x48/apps"
    mkdir -p "$pkg_dir/usr/share/doc/$pkg_name"
    
    # Copy relevant files based on package
    case "$pkg_name" in
        "tinkeros-desktop")
            cp -r "$OS_DIR/desktop"/* "$pkg_dir/usr/lib/tinker/desktop/"
            cp -r "$OS_DIR/brand/output/"* "$pkg_dir/usr/share/themes/TinkerOS/" 2>/dev/null || true
            ;;
        "tinkeros-system")
            cp -r "$OS_DIR/system"/* "$pkg_dir/usr/lib/tinker/system/"
            cp -r "$OS_DIR/systemd"/* "$pkg_dir/lib/systemd/system/" 2>/dev/null || true
            ;;
        "tinkeros-apps")
            cp -r "$OS_DIR/apps"/* "$pkg_dir/usr/lib/tinker/apps/"
            ;;
        "tinkeros-security")
            cp -r "$OS_DIR/security"/* "$pkg_dir/usr/lib/tinker/security/" 2>/dev/null || true
            ;;
        "tinkeros-gaming")
            cp -r "$OS_DIR/apps/gaming" "$pkg_dir/usr/lib/tinker/apps/gaming" 2>/dev/null || true
            ;;
        "tinkeros-dev")
            cp -r "$OS_DIR/apps"/* "$pkg_dir/usr/lib/tinker/apps/" 2>/dev/null || true
            ;;
        "tinkeros-enterprise")
            cp -r "$OS_DIR/enterprise" "$pkg_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-ai")
            cp -r "$OS_DIR/tinkerai" "$pkg_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-cowork")
            cp -r "$OS_DIR/tinker-cowork" "$pkg_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-control-center")
            cp -r "$OS_DIR/control-center" "$pkg_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
    esac
    
    # Create control file
    cat > "$pkg_dir/DEBIAN/control" << CONTROLEOF
Package: $pkg_name
Version: $VERSION
Architecture: $ARCH
Maintainer: TinkerOS Team <team@tinkeros.dev>
Description: $pkg_desc
 TinkerOS is a Linux-based operating system designed for everyone.
 It combines the power of Linux with the simplicity you expect.
Depends: bash, python3, python3-pyqt6, systemd
Section: utils
Priority: optional
Homepage: https://tinkeros.dev
CONTROLEOF
    
    # Create postinst script
    cat > "$pkg_dir/DEBIAN/postinst" << 'POSTINSTEOF'
#!/bin/bash
set -e

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

# Reload systemd
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
fi

# Enable services for tinkeros-system
if [ "$DPKG_MAINTSCRIPT_PACKAGE" = "tinkeros-system" ]; then
    systemctl enable NetworkManager systemd-timesyncd ufw 2>/dev/null || true
fi

exit 0
POSTINSTEOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"
    
    # Create prerm script
    cat > "$pkg_dir/DEBIAN/prerm" << 'PRERMEOF'
#!/bin/bash
set -e

# Disable services for tinkeros-system
if [ "$DPKG_MAINTSCRIPT_PACKAGE" = "tinkeros-system" ]; then
    systemctl disable ufw 2>/dev/null || true
fi

exit 0
PRERMEOF
    chmod 755 "$pkg_dir/DEBIAN/prerm"
    
    # Build package
    dpkg-deb --build "$pkg_dir" "$OUTPUT_DIR/${pkg_name}_${VERSION}_${ARCH}.deb"
    
    echo "Built: $OUTPUT_DIR/${pkg_name}_${VERSION}_${ARCH}.deb"
}

# Build all packages
echo "Building DEB packages..."
for pkg in "${!PACKAGES[@]}"; do
    create_package "$pkg" "${PACKAGES[$pkg]}"
done

echo "All packages built in $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.deb
