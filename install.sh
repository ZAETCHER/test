#!/bin/bash
# preflight.sh – Modern initialization for Debian-based systems

set -euo pipefail

# ----------------------------------------------------------------------
# Color Definitions (ANSI Escape Sequences)
# ----------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# ----------------------------------------------------------------------
# Helper: prompt with default Yes (Enter = Yes)
# ----------------------------------------------------------------------
prompt_yes_no() {
    local prompt="$1"
    local answer
    
    # Print the colored prompt text without a newline (-n)
    echo -e -n "${CYAN}${prompt} ${YELLOW}[Y/n]: ${NC}"
    
    # Read the user input safely
    read -r answer
    
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
echo -e "${BLUE}=== 🔍 Checking for sudo ===${NC}"
if ! command -v sudo &>/dev/null; then
    echo -e "${RED}❌ sudo is not installed on this system.${NC}"
    if prompt_yes_no "❓ Would you like to install sudo now?"; then
        echo -e "${GREEN}📥 Installing sudo (Root password required)...${NC}"
        
        if [[ $EUID -eq 0 ]]; then
            apt-get update && apt-get install -y sudo
            echo -e "${YELLOW}⚠️ You are running as root; skipping user group addition.${NC}"
            read -r -p "Press [Enter] to continue..."
        else
            su -c "apt-get update && apt-get install -y sudo && /usr/sbin/usermod -aG sudo $USER"
            
            # Wipes the screen for the critical logout section
            clear
            echo -e "${GREEN}==========================================================${NC}"
            echo -e "${GREEN}✅ User '${USER}' successfully added to the 'sudo' group!${NC}"
            echo -e "${GREEN}==========================================================${NC}"
            echo -e "${YELLOW}⚠️  IMPORTANT: You must log out and back in for changes to take effect.${NC}"
            echo -e "${GREEN}==========================================================${NC}"
            echo ""
            
            if prompt_yes_no "🚀 Would you like to log out now? (Recommended)"; then
                echo -e "${BLUE}🔄 Logging out... Goodbye!${NC}"
                sleep 1.5
                pkill -KILL -u "$USER"
            else
                clear
                echo -e "${YELLOW}==========================================================${NC}"
                echo -e "${YELLOW}👤 Manual logout selected.${NC}"
                echo -e "${YELLOW}==========================================================${NC}"
                echo -e "${RED}❌ Please log out and back in manually before re-running.${NC}"
                echo -e "${YELLOW}==========================================================${NC}"
                exit 0
            fi
        fi
    else
        echo -e "${RED}❌ Installation cancelled. Exiting.${NC}"
        exit 1
    fi
fi

# ----------------------------------------------------------------------
# 2. Verify that the current user can execute sudo commands
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 🔐 Checking sudo privileges ===${NC}"
if ! sudo -v; then
    echo -e "${RED}❌ ERROR: You do not have permission to run sudo commands.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Sudo privileges confirmed.${NC}"
sleep 1

# ----------------------------------------------------------------------
# 3. Perform system update and upgrade
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 🔄 Updating package lists and upgrading packages ===${NC}"
sudo apt-get update
sudo apt-get upgrade -y
echo -e "${GREEN}✅ System update and upgrade completed successfully!${NC}"
echo ""
read -r -p "Press [Enter] to proceed to optional tools..."

# ----------------------------------------------------------------------
# 4. Optional: install nala
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 📦 Optional: nala installation ===${NC}"
if command -v nala &>/dev/null; then
    echo -e "${YELLOW}📦 nala is already installed.${NC}"
else
    if prompt_yes_no "❓ Would you like to install 'nala' (a faster, prettier apt front-end)?"; then
        echo -e "${GREEN}📥 Installing nala...${NC}"
        sudo apt-get install -y nala
        echo -e "${GREEN}✅ nala installed successfully.${NC}"
    else
        echo -e "${YELLOW}⏭️ Skipping nala installation.${NC}"
    fi
fi
echo ""
read -r -p "Press [Enter] to finish..."

# ----------------------------------------------------------------------
# Final Status Screen
# ----------------------------------------------------------------------
clear
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}🎉   Pre-flight initialization completed!     🎉${NC}"
echo -e "${GREEN}===============================================${NC}"
