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
# Global Variables (Persistence Tracking)
# ----------------------------------------------------------------------
PKG_MGR="apt" # Default package manager fallback

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
read -r -p "Press [Enter] to proceed to package manager configuration..."

# ----------------------------------------------------------------------
# 4. Optional: Package Manager Selection (Apt vs Nala)
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 📦 Package Manager Enhancement Selection ===${NC}"
echo -e "By default, Debian uses ${CYAN}apt${NC}. However, you can upgrade to ${GREEN}nala${NC}."
echo -e ""
echo -e "${YELLOW}Why use Nala over standard Apt?${NC}"
echo -e "  🚀 ${GREEN}Parallel Downloads:${NC} Downloads multiple packages simultaneously (much faster)."
echo -e "  ✨ ${GREEN}Beautiful UI:${NC} Clean layout, clear error logs, and structural progress bars."
echo -e "  📜 ${GREEN}History Tracking:${NC} Easily undo, redo, or audit package installation history."
echo -e "  ⚡ ${GREEN}Smart Mirrors:${NC} Automatically tests and selects the fastest download mirrors."
echo -e "----------------------------------------------------------------------"

if prompt_yes_no "❓ Do you want to install Nala and use it for subsequent installations?"; then
    if command -v nala &>/dev/null; then
        echo -e "${YELLOW}📦 nala is already installed on this system.${NC}"
        PKG_MGR="nala"
    else
        echo -e "${GREEN}📥 Installing nala...${NC}"
        sudo apt-get install -y nala
        echo -e "${GREEN}✅ nala installed successfully.${NC}"
        PKG_MGR="nala"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping Nala. Staying with default standard 'apt'.${NC}"
    PKG_MGR="apt"
fi
echo ""
echo -e "ℹ️  Current package manager configuration set to: ${GREEN}$PKG_MGR${NC}"
read -r -p "Press [Enter] to view execution summary..."

# ----------------------------------------------------------------------
# Final Status Screen
# ----------------------------------------------------------------------
clear
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}🎉   Pre-flight initialization completed!     🎉${NC}"
echo -e "${GREEN}===============================================${NC}"
echo -e " Persistent System Settings Variable Set:"
echo -e " Preferred Package Manager: ${YELLOW}\$PKG_MGR${NC} -> ${GREEN}${PKG_MGR}${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""

# ----------------------------------------------------------------------
# FUTURE CODING EXAMPLE (How to use the variable later in your script):
# ----------------------------------------------------------------------
# echo "Installing curl and git using your preferred package manager..."
# sudo $PKG_MGR install -y curl git
