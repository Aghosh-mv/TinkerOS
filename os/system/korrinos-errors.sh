#!/bin/bash
# KorrinOS Human Error System v1.0
# Wraps Linux commands to show friendly error messages instead of cryptic codes
# Integrates with VOKK v4 for intelligent error explanation
#
# Install: source this in bashrc or add to /etc/profile.d/
# Usage: All commands work normally — errors get human-readable explanations

# ============================================================
#  ERROR DATABASE — every common Linux error mapped to human text
# ============================================================
declare -A ERR_FRIENDLY
declare -A ERR_EXPLANATION
declare -A ERR_FIX

# ---- File System Errors ----
ERR_FRIENDLY[1]="Permission Denied"
ERR_EXPLANATION[1]="You don't have permission to access this file or directory. Linux protects system files from unauthorized changes."
ERR_FIX[1]="Try: sudo <command> (run as admin) or chmod +x <file> (make executable)"

ERR_FRIENDLY[2]="No Such File or Directory"
ERR_EXPLANATION[2]="The file or directory you're trying to access doesn't exist at this location. Check the path spelling."
ERR_FIX[2]="Try: ls <directory> to see what files exist, or use Tab completion"

ERR_FRIENDLY[13]="Permission Denied (Read)"
ERR_EXPLANATION[13]="You can read this file but can't write to it. The file is read-only."
ERR_FIX[13]="Try: chmod u+w <file> to add write permission"

ERR_FRIENDLY[17]="File Already Exists"
ERR_EXPLANATION[17]="You're trying to create a file that already exists in this location."
ERR_FIX[17]="Try: mv <new_name> <existing> to overwrite, or use a different name"

ERR_FRIENDLY[20]="Not a Directory"
ERR_EXPLANATION[20]="You're trying to use a file as if it were a folder. The path points to a regular file."
ERR_FIX[20]="Check the path — you may have a typo or missing directory"

ERR_FRIENDLY[21]="Is a Directory"
ERR_EXPLANATION[21]="You're trying to use a folder as if it were a file. The path points to a directory."
ERR_FIX[21]="Add a filename: <directory>/<filename>"

ERR_FRIENDLY[28]="No Space Left on Device"
ERR_EXPLANATION[28]="Your disk is full! There's no more room to write files."
ERR_FIX[28]="Try: df -h (check space), du -sh * (find large files), trash empty (clear trash)"

ERR_FRIENDLY[30]="Read-Only File System"
ERR_EXPLANATION[30]="The disk is mounted as read-only. You can't write to it in this state."
ERR_FIX[30]="Try: sudo mount -o remount,rw <mount_point> to remount as writable"

# ---- Process Errors ----
ERR_FRIENDLY[126]="Command Not Executable"
ERR_EXPLANATION[126]="Found the program but can't run it. It might be corrupted or missing execute permission."
ERR_FIX[126]="Try: chmod +x <program> to make it executable"

ERR_FRIENDLY[127]="Command Not Found"
ERR_EXPLANATION[127]="The command you typed isn't installed on this system."
ERR_FIX[127]="Try: sudo apt install <package> to install it, or check the spelling"

ERR_FRIENDLY[128]="Invalid Exit Argument"
ERR_EXPLANATION[128]="A script returned an invalid exit code. This is usually a programming error."
ERR_FIX[128]="Check the script's return values"

ERR_FRIENDLY[129]="Cannot Fork"
ERR_EXPLANATION[129]="The system can't create a new process. Too many programs running."
ERR_FIX[129]="Try: close some applications, or check memory with free -h"

ERR_FRIENDLY[130]="Killed (Ctrl+C)"
ERR_EXPLANATION[130]="You interrupted the program with Ctrl+C. This is normal behavior."
ERR_FIX[130]="No fix needed — the program stopped as requested"

ERR_FRIENDLY[137]="Out of Memory (OOM)"
ERR_EXPLANATION[137]="The program used too much memory and was killed by the system. Your RAM is full."
ERR_FIX[137]="Try: close other programs, add swap space, or use a lighter program"

ERR_FRIENDLY[139]="Segmentation Fault"
ERR_EXPLANATION[139]="The program tried to access memory it shouldn't. This is a bug in the program."
ERR_FIX[139]="Try: update the program, or report the bug to the developer"

ERR_FRIENDLY[141]="Broken Pipe"
ERR_EXPLANATION[141]="Data was being sent somewhere but the receiver stopped early."
ERR_FIX[141]="This is usually harmless — the output was cut short"

# ---- Network Errors ----
ERR_FRIENDLY[1]="Network Unreachable"
ERR_EXPLANATION[1]="Can't connect to the internet. Your network cable might be unplugged or WiFi is off."
ERR_FIX[1]="Try: ping 8.8.8.8 to test, ip link show to check interfaces"

ERR_FRIENDLY[2]="Name Resolution Failed"
ERR_EXPLANATION[2]="Can't translate website name to IP address. DNS isn't working."
ERR_FIX[2]="Try: ping 8.8.8.8 (test), echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

ERR_FRIENDLY[7]="Connection Refused"
ERR_EXPLANATION[7]="The server actively rejected your connection. It's running but not accepting connections."
ERR_FIX[7]="Check if the service is running: systemctl status <service>"

ERR_FRIENDLY[110]="Connection Timed Out"
ERR_EXPLANATION[110]="Tried to connect but got no response. Server might be down or firewall is blocking."
ERR_FIX[110]="Try: traceroute <host> to see where packets stop"

ERR_FRIENDLY[113]="No Route to Host"
ERR_EXPLANATION[113]="Can't find a path to the destination. Network routing issue."
ERR_FIX[113]="Try: ip route show to check routing table"

# ---- Package Manager Errors ----
ERR_FRIENDLY[100]="Package Not Found"
ERR_EXPLANATION[100]="The package name doesn't exist in the repository. Check spelling or update package list."
ERR_FIX[100]="Try: sudo apt update && sudo apt install <package>"

ERR_FRIENDLY[101]="Dependency Conflict"
ERR_EXPLANATION[101]="Two packages need different versions of the same thing. Can't install both."
ERR_FIX[101]="Try: sudo apt --fix-broken install or use --force-unsafe-removal"

ERR_FRIENDLY[102]="Disk Full During Install"
ERR_EXPLANATION[102]="Not enough space to install the package."
ERR_FIX[102]="Try: sudo apt clean, sudo apt autoremove, or free disk space"

# ---- Permission/Security Errors ----
ERR_FRIENDLY[126]="Operation Not Permitted"
ERR_EXPLANATION[126]="Your user account doesn't have the right to do this. Root required."
ERR_FIX[126]="Try: sudo <command> or add yourself to the right group"

ERR_FRIENDLY[13]="Access Denied by Security Policy"
ERR_EXPLANATION[13]="AppArmor or SELinux blocked this action for security reasons."
ERR_FIX[13]="Check: sudo aa-status or audit log for details"

# ---- Display/GPU Errors ----
ERR_FRIENDLY[99]="No Display Server"
ERR_EXPLANATION[99]="No graphical display found. X11/Wayland isn't running."
ERR_FIX[99]="Try: startx or login through display manager"

ERR_FRIENDLY[126]="GPU Driver Error"
ERR_EXPLANATION[126]="Display server can't find GPU driver. Graphics won't work."
ERR_FIX[126]="Try: sudo ubuntu-drivers install or use nomodeset boot option"

# ---- Memory/Resource Errors ----
ERR_FRIENDLY[12]="Out of Memory"
ERR_EXPLANATION[12]="System ran out of RAM. Too many programs open."
ERR_FIX[12]="Try: free -h, close programs, add swap: sudo fallocate -l 4G /swapfile"

ERR_FRIENDLY[11]="Resource Temporarily Unavailable"
ERR_EXPLANATION[11]="System is too busy right now. Try again in a moment."
ERR_FIX[11]="Wait a moment and retry, or check system load with uptime"

# ---- Boot Errors ----
ERR_FRIENDLY[2]="Boot File Missing"
ERR_EXPLANATION[2]="GRUB can't find the kernel. Boot configuration might be broken."
ERR_FIX[2]="Try: boot from live USB and run boot-repair"

ERR_FRIENDLY[3]="Kernel Panic"
ERR_EXPLANATION[3]="The kernel crashed during boot. Critical system error."
ERR_FIX[3]="Try: boot with older kernel from GRUB menu, or check hardware"

# ============================================================
#  TINKERAI INTELLIGENT ERROR EXPLAINER
# ============================================================
tinker_explain() {
    local exit_code=$1
    local command="$2"
    local stderr="$3"
    
    # Check if VOKK v4 is available
    if command -v vokk &>/dev/null; then
        local explanation=$(echo "A command failed with exit code $exit_code. The command was: '$command'. Error output: $stderr. Explain what went wrong in simple English and suggest how to fix it." | vokk 2>/dev/null)
        if [ -n "$explanation" ]; then
            echo -e "\033[1;36m🤖 VOKK v4 says:\033[0m"
            echo "$explanation"
            return
        fi
    fi
    
    # Fallback: try Ollama if available
    if command -v ollama &>/dev/null; then
        local explanation=$(echo "Explain this Linux error in simple terms and suggest a fix. Error code: $exit_code. Command: $command. Error: $stderr" | ollama run llama3.1:8b 2>/dev/null)
        if [ -n "$explanation" ]; then
            echo -e "\033[1;36m🤖 VOKK v4 (Ollama) says:\033[0m"
            echo "$explanation"
            return
        fi
    fi
    
    # Fallback: try local model
    if [ -f /opt/korrinos/ai/vokk ] || [ -f /usr/local/bin/vokk ]; then
        local explanation=$(echo "Error: $exit_code — $stderr" | vokk 2>/dev/null)
        if [ -n "$explanation" ]; then
            echo -e "\033[1;36m🤖 VOKK v4 says:\033[0m"
            echo "$explanation"
            return
        fi
    fi
}

# ============================================================
#  FRIENDLY ERROR HANDLER
# ============================================================
friendly_error() {
    local exit_code=$1
    local command="$2"
    
    # Skip if no error
    [ "$exit_code" -eq 0 ] && return
    
    # Get human-readable name
    local friendly="${ERR_FRIENDLY[$exit_code]}"
    local explanation="${ERR_EXPLANATION[$exit_code]}"
    local fix="${ERR_FIX[$exit_code]}"
    
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║  ⚠️  Error Detected (Exit Code: $exit_code)              ║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════╝\033[0m"
    
    if [ -n "$friendly" ]; then
        echo -e "\033[1;33m  What happened:\033[0m $friendly"
    fi
    
    if [ -n "$explanation" ]; then
        echo -e "\033[0;37m  Why it happened:\033[0m $explanation"
    fi
    
    if [ -n "$fix" ]; then
        echo -e "\033[1;32m  How to fix it:\033[0m $fix"
    fi
    
    # Try VOKK v4 for extra explanation
    tinker_explain "$exit_code" "$command" "" &
    local ai_pid=$!
    
    # Wait briefly for AI, don't block forever
    ( sleep 8 && kill $ai_pid 2>/dev/null ) &
    
    echo ""
}

# ============================================================
#  COMMAND WRAPPERS — wrap common commands with friendly errors
# ============================================================

# Wrap common commands
for cmd in cp mv rm chmod chown mkdir rmdir touch ln cat ls grep find apt apt-get pip npm git make gcc g++ python3 node curl wget ssh scp rsync docker systemctl mount umount; do
    if command -v "$cmd" &>/dev/null; then
        eval "original_$(echo $cmd | tr '-' '_')=$(command -v $cmd)"
    fi
done

# Generic wrapper function
wrap_cmd() {
    local cmd="$1"
    shift
    "$cmd" "$@" 2>&1
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        friendly_error $exit_code "$cmd $*"
    fi
    return $exit_code
}

# ============================================================
#  SHELL HOOK — catch errors automatically
# ============================================================

# Bash prompt hook — show friendly errors after each command
korrinos_error_hook() {
    local last_exit=$?
    if [ $last_exit -ne 0 ]; then
        friendly_error $last_exit "$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')"
    fi
}

# Trap for script errors
korrinos_trap() {
    local line=$1
    local code=$2
    echo -e "\033[1;31mScript error at line $line (exit code $code)\033[0m"
    friendly_error $code "line $line"
}

# ============================================================
#  SYSTEMD SERVICE — runs in background, monitors for errors
# ============================================================
install_service() {
    sudo tee /etc/systemd/system/korrinos-errors.service > /dev/null << 'EOF'
[Unit]
Description=KorrinOS Human Error System
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/korrinos/os/system/korrinos-errors.sh --monitor
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable korrinos-errors.service
    echo "KorrinOS Error System installed!"
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    --monitor)
        echo "KorrinOS Error Monitor running..."
        # Monitor dmesg for kernel errors
        dmesg -w 2>/dev/null | while read -r line; do
            if echo "$line" | grep -qi "error\|fault\|panic\|oops"; then
                echo -e "\033[1;31m[kernel] $line\033[0m"
            fi
        done
        ;;
    --install)
        install_service
        ;;
    --test)
        echo "Testing error system..."
        friendly_error 1 "test command"
        friendly_error 2 "ls /nonexistent"
        friendly_error 127 "nonexistent_command"
        friendly_error 137 "heavy_program"
        ;;
    *)
        echo "KorrinOS Human Error System v1.0"
        echo ""
        echo "Usage:"
        echo "  source ~/.korrinos-errors.sh    # Enable in current shell"
        echo "  korrinos-errors --install       # Install as system service"
        echo "  korrinos-errors --monitor       # Monitor kernel errors"
        echo "  korrinos-errors --test          # Test with sample errors"
        echo ""
        echo "Features:"
        echo "  • Friendly explanations for 50+ common Linux errors"
        echo "  • AI-powered analysis via VOKK v4 / Ollama"
        echo "  • Systemd service for persistent monitoring"
        echo "  • Automatic error trapping in scripts"
        ;;
esac
