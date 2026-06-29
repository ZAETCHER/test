#!/bin/bash
# preflight.sh – Streamlined initialization for Debian-based systems

set -euo pipefail

# ----------------------------------------------------------------------
# Helper: prompt with default Yes (Enter = Yes)
# ----------------------------------------------------------------------
prompt_yes_no() {
    local prompt="$1"
    local answer
    read -r -p "$prompt [Y/n]: " answer
    case "$answer" in
        [Nn]*) return 1 ;;
        *)     return 0 ;;
    esac
}

# ----------------------------------------------------------------------
# 1. Check if sudo is installed
# ----------------------------------------------------------------------
echo "=== Checking for sudo ==="
if ! command -v sudo &>/dev/null; then
    echo "[-] sudo is not installed."
    if prompt_yes_no "[?] Would you like to install sudo now?"; then
        echo "[+] Installing sudo (Root password required)..."
        
        if [[ $EUID -eq 0 ]]; then
            apt update && apt install -y sudo
            echo "[*] You are running as root; skipping user group addition."
        else
            su -c "apt-get update && apt-get install -y sudo && usermod -aG sudo $USER"
            echo "[+] User '$USER' added to the 'sudo' group."
            echo "[!] IMPORTANT: Please log out and back in for changes to take effect, then re-run this script."
            exit 0
        fi
    else
        echo "[-] Installation cancelled. Exiting."
        exit 1
    fi
fi

# ----------------------------------------------------------------------
# 2. Verify that the current user can execute sudo commands
# ----------------------------------------------------------------------
echo "=== Checking sudo privileges ==="
if ! sudo -v; then
    echo "[-] ERROR: You do not have permission to run sudo commands."
    exit 1
fi
echo "[+] Sudo privileges confirmed."

# ----------------------------------------------------------------------
# 3. Perform system update and upgrade
# ----------------------------------------------------------------------
echo "=== Updating package lists and upgrading packages ==="
sudo apt update
sudo apt upgrade -y

# ----------------------------------------------------------------------
# 4. Optional: install nala
# ----------------------------------------------------------------------
echo "=== Optional: nala installation ==="
if command -v nala &>/dev/null; then
    echo "[*] nala is already installed."
else
    if prompt_yes_no "[?] Would you like to install 'nala' (a faster, prettier apt front-end)?"; then
        echo "[+] Installing nala..."
        sudo apt install -y nala
        echo "[+] nala installed successfully."
    else
        echo "[*] Skipping nala installation."
    fi
fi

echo "============================================"
echo "   Pre-flight initialization completed!     "
echo "============================================"
