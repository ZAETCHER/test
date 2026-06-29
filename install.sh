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

# Clear the screen right at the launch of the script
clear

# ----------------------------------------------------------------------
# 1. Check if sudo is installed
# ----------------------------------------------------------------------
echo "=== Checking for sudo ==="
if ! command -v sudo &>/dev/null; then
    echo "[-] sudo is not installed."
    if prompt_yes_no "[?] Would you like to install sudo now?"; then
        echo "[+] Installing sudo (Root password required)..."
        
        if [[ $EUID -eq 0 ]]; then
            apt-get update && apt-get install -y sudo
            echo "[*] You are running as root; skipping user group addition."
            read -p "Press [Enter] to continue..."
       else
            # Install sudo and add user to group using absolute path
            su -c "apt-get update && apt-get install -y sudo && /usr/sbin/usermod -aG sudo $USER"
            
            # Wipes the screen so the user only sees the critical next steps
            clear
            echo "=========================================================="
            echo "[+] User '$USER' successfully added to the 'sudo' group."
            echo "=========================================================="
            echo "[!] IMPORTANT: You must log out and back in for changes to take effect."
            echo "=========================================================="
            echo ""
            
            if prompt_yes_no "[?] Would you like to log out now? (Recommended)"; then
                echo "[+] Logging out..."
                sleep 1
                # Kills all processes owned by the current user, forcing an instant logout
                pkill -KILL -u "$USER"
            else
                clear
                echo "=========================================================="
                echo "[*] Manual logout required."
                echo "=========================================================="
                echo "[!] Please log out and back in manually before re-running this script."
                echo "=========================================================="
                exit 0
            fi
        fi
    else
        echo "[-] Error: 'sudo' is required to proceed. Exiting."
        exit 1
    fi
fi

# ----------------------------------------------------------------------
# 2. Verify that the current user can execute sudo commands
# ----------------------------------------------------------------------
clear
echo "=== Checking sudo privileges ==="
if ! sudo -v; then
    echo "[-] ERROR: You do not have permission to run sudo commands."
    exit 1
fi
echo "[+] Sudo privileges confirmed."
sleep 1

# ----------------------------------------------------------------------
# 3. Perform system update and upgrade
# ----------------------------------------------------------------------
clear
echo "=== Updating package lists and upgrading packages ==="
sudo apt-get update
sudo apt-get upgrade -y
echo "[+] System update and upgrade completed."
read -p "Press [Enter] to proceed to optional tools..."

# ----------------------------------------------------------------------
# 4. Optional: install nala
# ----------------------------------------------------------------------
clear
echo "=== Optional: nala installation ==="
if command -v nala &>/dev/null; then
    echo "[*] nala is already installed."
else
    if prompt_yes_no "[?] Would you like to install 'nala' (a faster, prettier apt front-end)?"; then
        echo "[+] Installing nala..."
        sudo apt-get install -y nala
        echo "[+] nala installed successfully."
    else
        echo "[*] Skipping nala installation."
    fi
fi
read -p "Press [Enter] to finish..."

# ----------------------------------------------------------------------
# Final Status Screen
# ----------------------------------------------------------------------
clear
echo "============================================"
echo "   Pre-flight initialization completed!     "
echo "============================================"
