#!/bin/bash
# TinkerOS Password Monitor
# Detects password fields and offers secure generation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAULT_CMD="tinker-vault"
NOTIFY_ICON="password-manager"
CHECK_INTERVAL=1
ACTIVE_BROWSER=""

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            TINKEROS PASSWORD MONITOR                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Detect active browser
detect_browser() {
    local window=$(xdotool getactivewindow getwindowname 2>/dev/null)
    
    case "$window" in
        *Firefox*|*firefox*)
            ACTIVE_BROWSER="firefox"
            return 0
            ;;
        *Chromium*|*chromium*|*Chrome*|*chrome*)
            ACTIVE_BROWSER="chromium"
            return 0
            ;;
        *Brave*|*brave*)
            ACTIVE_BROWSER="brave"
            return 0
            ;;
        *Vivaldi*|*vivaldi*)
            ACTIVE_BROWSER="vivaldi"
            return 0
            ;;
        *Opera*|*opera*)
            ACTIVE_BROWSER="opera"
            return 0
            ;;
        *)
            ACTIVE_BROWSER=""
            return 1
            ;;
    esac
}

# Get current website URL (browser-specific)
get_current_url() {
    case "$ACTIVE_BROWSER" in
        firefox)
            # Firefox with xdotool
            xdotool key ctrl+l
            sleep 0.2
            xdotool key ctrl+c
            sleep 0.1
            xclip -selection clipboard -o 2>/dev/null
            ;;
        chromium|chrome|brave|vivaldi|opera)
            # Chrome-based browsers
            xdotool key ctrl+l
            sleep 0.2
            xdotool key ctrl+c
            sleep 0.1
            xclip -selection clipboard -o 2>/dev/null
            ;;
        *)
            echo ""
            ;;
    esac
}

# Extract domain from URL
extract_domain() {
    local url=$1
    
    # Remove protocol
    local domain=$(echo "$url" | sed -E 's|https?://||')
    
    # Remove path
    domain=$(echo "$domain" | cut -d'/' -f1)
    
    # Remove www.
    domain=$(echo "$domain" | sed 's/^www\.//')
    
    echo "$domain"
}

# Show password offer popup
show_password_offer() {
    local domain=$1
    
    if command -v notify-send >/dev/null 2>&1; then
        # Create notification with actions
        notify-send -u critical -i $NOTIFY_ICON \
            "🔐 Password Manager" \
            "Password field detected on $domain\n\nWould you like to:" \
            --action="generate=Generate Strong Password" \
            --action="use_existing=Use Existing Password" \
            --action="skip=Skip"
    else
        # Fallback to terminal prompt
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║               PASSWORD MANAGER ALERT                    ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  Password field detected on: ${GREEN}$domain${NC}"
        echo ""
        echo "  Options:"
        echo "    1) Generate strong password"
        echo "    2) Use existing password"
        echo "    3) Skip"
        echo ""
        read -p "  Choose (1-3): " choice
        
        case $choice in
            1) generate_and_save "$domain" ;;
            2) use_existing "$domain" ;;
            3) echo "  Skipped." ;;
        esac
    fi
}

# Generate and save password for domain
generate_and_save() {
    local domain=$1
    
    echo -e "${YELLOW}Generating password for: $domain${NC}"
    
    # Generate password
    local password=$($VAULT_CMD generate 20)
    
    # Get username
    echo -e "  Generated password: ${CYAN}$password${NC}"
    echo ""
    read -p "  Enter username/email: " username
    
    if [ -n "$username" ]; then
        # Save to vault
        $VAULT_CMD add "$domain" "$username" "$password"
        
        echo ""
        echo -e "${GREEN}✓ Password saved securely!${NC}"
        echo -e "  Site: $domain"
        echo -e "  Username: $username"
        echo -e "  Password: $password"
        echo ""
        
        # Copy password to clipboard
        echo "$password" | xclip -selection clipboard
        echo -e "${GREEN}✓ Password copied to clipboard${NC}"
        
        # Show notification
        notify-send -u normal -i $NOTIFY_ICON \
            "Password Saved" \
            "Password for $domain has been generated and saved.\nCopied to clipboard."
    fi
}

# Use existing password
use_existing() {
    local domain=$1
    
    local credentials=$($VAULT_CMD get "$domain")
    
    if [ -n "$credentials" ]; then
        local username=$(echo "$credentials" | cut -d: -f1)
        local password=$(echo "$credentials" | cut -d: -f2)
        
        echo -e "${GREEN}Found credentials for: $domain${NC}"
        echo -e "  Username: $username"
        echo -e "  Password: ****"
        echo ""
        
        # Auto-fill
        read -p "  Auto-fill? (y/n): " fill_choice
        
        if [ "$fill_choice" = "y" ] || [ "$fill_choice" = "Y" ]; then
            # Type username
            xdotool type --delay 50 "$username"
            xdotool key Tab
            sleep 0.3
            
            # Type password
            xdotool type --delay 50 "$password"
            
            echo -e "${GREEN}✓ Credentials filled!${NC}"
        fi
        
        # Copy password
        echo "$password" | xclip -selection clipboard
        echo -e "${GREEN}✓ Password copied to clipboard${NC}"
    else
        echo -e "${YELLOW}No saved password for: $domain${NC}"
        echo "  Would you like to generate one? (y/n)"
        read -p "  > " gen_choice
        
        if [ "$gen_choice" = "y" ] || [ "$gen_choice" = "Y" ]; then
            generate_and_save "$domain"
        fi
    fi
}

# Monitor for password fields
monitor_password_fields() {
    echo -e "${YELLOW}Password Monitor Active${NC}"
    echo "Watching for password fields..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    local last_window=""
    local cooldown=0
    
    while true; do
        # Get current window
        local current_window=$(xdotool getactivewindow 2>/dev/null)
        local window_name=$(xdotool getactivewindow getwindowname 2>/dev/null)
        
        # Check if browser window changed
        if [ "$current_window" != "$last_window" ]; then
            last_window=$current_window
            
            # Check if it's a browser
            if detect_browser; then
                # Check for password field indicators
                # This is a simplified check - real implementation would use browser extension
                if echo "$window_name" | grep -qi "login\|signin\|sign-in\|account\|password\|auth"; then
                    if [ $cooldown -eq 0 ]; then
                        local url=$(get_current_url)
                        local domain=$(extract_domain "$url")
                        
                        if [ -n "$domain" ]; then
                            show_password_offer "$domain"
                            cooldown=30  # 30 second cooldown
                        fi
                    fi
                fi
            fi
        fi
        
        # Cooldown timer
        if [ $cooldown -gt 0 ]; then
            cooldown=$((cooldown - 1))
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Install browser extension
install_browser_extension() {
    echo -e "${YELLOW}Installing Browser Extension${NC}"
    echo ""
    
    case "$ACTIVE_BROWSER" in
        firefox)
            echo "For Firefox, install the TinkerOS extension:"
            echo "  1. Open Firefox"
            echo "  2. Go to about:debugging"
            echo "  3. Click 'Load Temporary Add-on'"
            echo "  4. Select: $HOME/.tinker/browser-extension/firefox/"
            ;;
        chromium|chrome|brave|vivaldi|opera)
            echo "For Chrome-based browsers:"
            echo "  1. Open your browser"
            echo "  2. Go to chrome://extensions/"
            echo "  3. Enable 'Developer mode'"
            echo "  4. Click 'Load unpacked'"
            echo "  5. Select: $HOME/.tinker/browser-extension/chrome/"
            ;;
        *)
            echo "No browser detected. Please open a browser first."
            ;;
    esac
    echo ""
}

# Create browser extension
create_browser_extension() {
    local ext_dir="$HOME/.tinker/browser-extension"
    
    mkdir -p "$ext_dir/chrome" "$ext_dir/firefox"
    
    # Chrome manifest
    cat > "$ext_dir/chrome/manifest.json" << 'EOF'
{
    "manifest_version": 3,
    "name": "TinkerOS Password Manager",
    "version": "1.0",
    "description": "Secure password generation and storage",
    "permissions": ["activeTab", "storage", "notifications"],
    "action": {
        "default_popup": "popup.html",
        "default_icon": "icon.png"
    },
    "content_scripts": [
        {
            "matches": ["<all_urls>"],
            "js": ["content.js"],
            "run_at": "document_idle"
        }
    ],
    "background": {
        "service_worker": "background.js"
    }
}
EOF
    
    # Content script for detecting password fields
    cat > "$ext_dir/chrome/content.js" << 'EOF'
// TinkerOS Password Manager - Content Script
// Detects password fields and communicates with native messaging

(function() {
    'use strict';
    
    // Monitor for password fields
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.nodeType === Node.ELEMENT_NODE) {
                    checkForPasswordFields(node);
                }
            });
        });
    });
    
    // Start observing
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    // Check for password fields
    function checkForPasswordFields(element) {
        const passwordFields = element.querySelectorAll 
            ? element.querySelectorAll('input[type="password"]')
            : [];
        
        passwordFields.forEach((field) => {
            if (!field.dataset.tinkerMonitored) {
                field.dataset.tinkerMonitored = 'true';
                
                // Notify background script
                chrome.runtime.sendMessage({
                    action: 'passwordFieldDetected',
                    url: window.location.href,
                    domain: window.location.hostname
                });
                
                // Add focus listener
                field.addEventListener('focus', () => {
                    chrome.runtime.sendMessage({
                        action: 'passwordFieldFocused',
                        url: window.location.href,
                        domain: window.location.hostname
                    });
                });
            }
        });
    }
    
    // Check existing fields
    checkForPasswordFields(document);
})();
EOF
    
    # Background script
    cat > "$ext_dir/chrome/background.js" << 'EOF'
// TinkerOS Password Manager - Background Script

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'passwordFieldDetected' || 
        message.action === 'passwordFieldFocused') {
        
        // Show notification
        chrome.notifications.create({
            type: 'basic',
            iconUrl: 'icon.png',
            title: 'TinkerOS Password Manager',
            message: `Password field detected on ${message.domain}`,
            buttons: [
                { title: 'Generate Password' },
                { title: 'Use Existing' }
            ],
            priority: 2
        });
    }
});

// Handle notification clicks
chrome.notifications.onClicked.addListener((notificationId) => {
    // Open popup
    chrome.action.openPopup();
});
EOF
    
    # Popup HTML
    cat > "$ext_dir/chrome/popup.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>TinkerOS Password Manager</title>
    <style>
        body {
            width: 300px;
            padding: 15px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #1a1b26;
            color: #c0caf5;
        }
        h1 {
            margin: 0 0 15px 0;
            font-size: 16px;
            color: #7aa2f7;
        }
        .btn {
            display: block;
            width: 100%;
            padding: 10px;
            margin: 5px 0;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }
        .btn-primary {
            background: #7aa2f7;
            color: #1a1b26;
        }
        .btn-secondary {
            background: #3b4261;
            color: #c0caf5;
        }
        .btn:hover {
            opacity: 0.9;
        }
        .status {
            margin-top: 15px;
            padding: 10px;
            background: #24283b;
            border-radius: 5px;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <h1>🔐 TinkerOS Password Manager</h1>
    <button class="btn btn-primary" id="generate">Generate Strong Password</button>
    <button class="btn btn-secondary" id="useExisting">Use Existing Password</button>
    <button class="btn btn-secondary" id="openManager">Open Password Manager</button>
    <div class="status" id="status">Ready</div>
    
    <script src="popup.js"></script>
</body>
</html>
EOF
    
    # Popup JavaScript
    cat > "$ext_dir/chrome/popup.js" << 'EOF'
document.getElementById('generate').addEventListener('click', () => {
    // Generate password via native messaging
    chrome.runtime.sendMessage({ action: 'generatePassword' });
    document.getElementById('status').textContent = 'Password generated!';
});

document.getElementById('useExisting').addEventListener('click', () => {
    // Get password via native messaging
    chrome.runtime.sendMessage({ action: 'getPassword' });
});

document.getElementById('openManager').addEventListener('click', () => {
    // Open native password manager
    chrome.runtime.sendMessage({ action: 'openManager' });
});
EOF
    
    echo -e "${GREEN}✓ Browser extension created!${NC}"
    echo ""
    echo "Extension location: $ext_dir"
    echo ""
}

show_help() {
    echo "Usage: tinker-password-monitor [command]"
    echo ""
    echo "Commands:"
    echo "  start           Start monitoring for password fields"
    echo "  stop            Stop monitoring"
    echo "  install-ext     Install browser extension"
    echo "  create-ext      Create browser extension files"
    echo "  help            Show this help"
    echo ""
    echo "Features:"
    echo "  • Detects password fields in browsers"
    echo "  • Offers to generate strong passwords"
    echo "  • Auto-fills saved credentials"
    echo "  • Secure local storage"
    echo ""
}

# Main
case "$1" in
    start|monitor)
        show_header
        monitor_password_fields
        ;;
    stop)
        pkill -f "tinker-password-monitor" 2>/dev/null
        echo -e "${GREEN}✓ Monitor stopped${NC}"
        ;;
    install-ext)
        show_header
        install_browser_extension
        ;;
    create-ext)
        show_header
        create_browser_extension
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_header
        echo -e "${YELLOW}TinkerOS Password Monitor${NC}"
        echo ""
        echo "Detects password fields and offers secure generation."
        echo ""
        echo "Quick commands:"
        echo "  tinker-password-monitor start     - Start monitoring"
        echo "  tinker-password-monitor install-ext - Install extension"
        ;;
esac
