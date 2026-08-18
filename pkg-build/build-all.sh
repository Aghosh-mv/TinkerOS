#!/bin/bash
# Build all package formats

set -e

echo "========================================="
echo "TinkerOS Package Builder"
echo "========================================="

echo ""
echo "Building DEB packages..."
./build-deb.sh

echo ""
echo "Building RPM packages..."
./build-rpm.sh

echo ""
echo "========================================="
echo "All packages built!"
echo "========================================="
ls -la "$HOME/Desktop/TinkerOS-Packages"/*.deb 2>/dev/null || true
ls -la "$HOME/Desktop/TinkerOS-Packages"/*.rpm 2>/dev/null || true
