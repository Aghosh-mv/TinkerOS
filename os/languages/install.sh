#!/bin/bash
# KorrinOS Language Integration — Korlang + KorrinUILang
# Installs both languages into the KorrinOS system
set -euo pipefail

INSTALL_DIR="/opt/korrinos/os/languages"
BIN_DIR="/usr/local/bin"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  KorrinOS Language Integration                              ║"
echo "║  Korlang + KorrinUILang                                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "Error: Python 3 required"
    exit 1
fi

# Check GCC
if ! command -v gcc &>/dev/null; then
    echo "Warning: GCC not found. Install with: sudo apt install gcc"
fi

# Install Korlang
echo "Installing Korlang..."
mkdir -p "$INSTALL_DIR/korlang"
cp korlang.py "$INSTALL_DIR/korlang/"
chmod +x "$INSTALL_DIR/korlang/korlang.py"

# Create wrapper script
cat > "$BIN_DIR/korlang" << 'WRAPPER'
#!/bin/bash
exec python3 /opt/korrinos/os/languages/korlang/korlang.py "$@"
WRAPPER
chmod +x "$BIN_DIR/korlang"
echo "  Korlang installed: $(which korlang)"

# Install KorrinUILang
echo "Installing KorrinUILang..."
mkdir -p "$INSTALL_DIR/korrinuilang"
cp korrinuilang.py "$INSTALL_DIR/korrinuilang/"
chmod +x "$INSTALL_DIR/korrinuilang/korrinuilang.py"

# Create wrapper script
cat > "$BIN_DIR/korrinuilang" << 'WRAPPER'
#!/bin/bash
exec python3 /opt/korrinos/os/languages/korrinuilang/korrinuilang.py "$@"
WRAPPER
chmod +x "$BIN_DIR/korrinuilang"
echo "  KorrinUILang installed: $(which korrinuilang)"

# Install examples
echo "Installing examples..."
mkdir -p /opt/korrinos/os/languages/demo
cp examples/*.kor /opt/korrinos/os/languages/demo/ 2>/dev/null || true
cp examples/*.kui /opt/korrinos/os/languages/demo/ 2>/dev/null || true

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installation complete!                                     ║"
echo "║                                                              ║"
echo "║  Usage:                                                      ║"
echo "║    korlang <file.kor> [--run] [--emit-c]                    ║"
echo "║    korrinuilang <file.kui> [--run]                           ║"
echo "║                                                              ║"
echo "║  Examples:                                                   ║"
echo "║    korlang /opt/korrinos/os/languages/demo/hello.kor --run  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
