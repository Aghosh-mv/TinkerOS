#!/bin/bash
# TinkerOS RPM Package Builder

set -e

ROOT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
OS_DIR="$ROOT_DIR/os"
BUILD_DIR="/tmp/tinker-rpm-build"
OUTPUT_DIR="$HOME/Desktop/TinkerOS-Packages"
VERSION="7.2.0"
RELEASE="1"
ARCH="x86_64"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

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

create_rpm() {
    local pkg_name="$1"
    local pkg_desc="$2"
    local spec_file="$HOME/rpmbuild/SPECS/${pkg_name}.spec"
    local build_dir="$BUILD_DIR/$pkg_name"
    
    echo "Building $pkg_name RPM..."
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir/usr/lib/tinker"
    mkdir -p "$build_dir/usr/bin"
    mkdir -p "$build_dir/usr/share/applications"
    mkdir -p "$build_dir/usr/share/icons/hicolor/48x48/apps"
    mkdir -p "$build_dir/usr/share/doc/$pkg_name"
    
    # Copy files (same as deb)
    case "$pkg_name" in
        "tinkeros-desktop")
            cp -r "$OS_DIR/desktop"/* "$build_dir/usr/lib/tinker/desktop/"
            cp -r "$OS_DIR/brand/output/"* "$build_dir/usr/share/themes/TinkerOS/" 2>/dev/null || true
            ;;
        "tinkeros-system")
            cp -r "$OS_DIR/system"/* "$build_dir/usr/lib/tinker/system/"
            cp -r "$OS_DIR/systemd"/* "$build_dir/lib/systemd/system/" 2>/dev/null || true
            ;;
        "tinkeros-apps")
            cp -r "$OS_DIR/apps"/* "$build_dir/usr/lib/tinker/apps/"
            ;;
        "tinkeros-security")
            cp -r "$OS_DIR/security"/* "$build_dir/usr/lib/tinker/security/" 2>/dev/null || true
            ;;
        "tinkeros-gaming")
            cp -r "$OS_DIR/apps/gaming" "$build_dir/usr/lib/tinker/apps/gaming" 2>/dev/null || true
            ;;
        "tinkeros-dev")
            cp -r "$OS_DIR/apps"/* "$build_dir/usr/lib/tinker/apps/" 2>/dev/null || true
            ;;
        "tinkeros-enterprise")
            cp -r "$OS_DIR/enterprise" "$build_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-ai")
            cp -r "$OS_DIR/tinkerai" "$build_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-cowork")
            cp -r "$OS_DIR/tinker-cowork" "$build_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
        "tinkeros-control-center")
            cp -r "$OS_DIR/control-center" "$build_dir/usr/lib/tinker/" 2>/dev/null || true
            ;;
    esac
    
    # Create tarball
    tar -czf ~/rpmbuild/SOURCES/${pkg_name}-${VERSION}.tar.gz -C "$build_dir" .
    
    # Create spec file
    cat > "$spec_file" << SPECEOF
Name:           $pkg_name
Version:        $VERSION
Release:        $RELEASE
Summary:        $pkg_desc
License:        GPL-3.0
URL:            https://tinkeros.dev
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64
Requires:       bash, python3, python3-qt6, systemd
%description
$pkg_desc

TinkerOS is a Linux-based operating system designed for everyone.
It combines the power of Linux with the simplicity you expect.

%prep
%autosetup -n %{name}-%{version}

%build
# No build step needed

%install
rm -rf %{buildroot}
cp -r * %{buildroot}/

%files
/usr/lib/tinker
/usr/bin
/usr/share/applications
/usr/share/icons
/usr/share/doc/%{name}

%post
update-desktop-database /usr/share/applications 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

%preun
if [ \$1 -eq 0 ]; then
    systemctl disable ufw 2>/dev/null || true
fi

%changelog
* $(date +"%a %b %d %Y") TinkerOS Team <team@tinkeros.dev> - $VERSION-$RELEASE
- Initial release
SPECEOF
    
    # Build RPM
    rpmbuild -ba "$spec_file"
    
    # Copy to output
    cp ~/rpmbuild/RPMS/x86_64/${pkg_name}-${VERSION}-${RELEASE}.x86_64.rpm "$OUTPUT_DIR/"
    
    echo "Built: $OUTPUT_DIR/${pkg_name}-${VERSION}-${RELEASE}.x86_64.rpm"
}

# Build all packages
echo "Building RPM packages..."
for pkg in "${!PACKAGES[@]}"; do
    create_rpm "$pkg" "${PACKAGES[$pkg]}"
done

echo "All RPM packages built in $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.rpm
