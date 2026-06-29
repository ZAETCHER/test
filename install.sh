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

# ======================================================================
# WELCOME SCREEN & ASCII ART
# ======================================================================
clear
echo -e "${CYAN}"
echo " __      __  _____    _______  ______   _____          _   _ "
echo " \ \    / / |  __ \  |  _____||  ____ \ |_   _|   /\   | \ | |"
echo "  \ \  / /  | |__) | | |__    | |___) |  | |     /  \  |  \| |"
echo "   \ \/ /   |  _  /  |  __|   |  ____ (  | |    / /\ \ | . \ |"
echo "    \  /    | | \ \  | |____  | |___) | _| |_  / ____ \| |\  |"
echo "     \/     |_|  \_\ |_______||______/ |_____|/_/    \_\_| \_|"
echo -e "${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}⚡ WHAT?${NC}"
echo -e "  A zero-fuss Bash script for a minimal GNOME/KDE install on Debian 13—"
echo -e "  no cruft, no bloatware, just the bare essentials."
echo ""
echo -e "${YELLOW}⚡ WHY?${NC}"
echo -e "  Because 'apt install gnome' pulls in 500+ packages you'll never use."
echo -e "  This script trims the fat, installing only the core DE components so"
echo -e "  you get a lean, responsive desktop that doesn't waste disk, memory,"
echo -e "  or CPU cycles. Perfect for minimalists, homelabbers, and anyone who"
echo -e "  actually knows what they want on their system."
echo ""
echo -e "${YELLOW}🎯 TARGET:${NC} Debian 13 (Trixie) and current Debian-derived distributions."
echo -e "${GREEN}======================================================================${NC}"
echo ""
read -r -p "Press [Enter] to start pre-flight environment checks..."


# ----------------------------------------------------------------------
# 1. Check if sudo is installed
# ----------------------------------------------------------------------
clear
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
# 3. Check and Configure Debian Repositories (contrib non-free non-free-firmware)
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 📋 Checking Repository Components ===${NC}"

# Check if components are missing from active lines in sources.list
MISSING_COMPONENTS=""
if ! grep -E '^deb(-src)?\s+' /etc/apt/sources.list | grep -q 'contrib'; then
    MISSING_COMPONENTS="contrib"
fi
if ! grep -E '^deb(-src)?\s+' /etc/apt/sources.list | grep -q 'non-free '; then
    MISSING_COMPONENTS="${MISSING_COMPONENTS:+$MISSING_COMPONENTS }non-free"
fi
if ! grep -E '^deb(-src)?\s+' /etc/apt/sources.list | grep -q 'non-free-firmware'; then
    MISSING_COMPONENTS="${MISSING_COMPONENTS:+$MISSING_COMPONENTS }non-free-firmware"
fi

if [ -n "$MISSING_COMPONENTS" ]; then
    echo -e "${YELLOW}⚠️  Your /etc/apt/sources.list is missing: ${MISSING_COMPONENTS}${NC}"
    if prompt_yes_no "❓ Would you like to smoothly append these components after 'main'?"; then
        echo -e "${GREEN}⚙️ Updating repository paths...${NC}"
        
        # 1. Safely back up the current sources.list just in case
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        # 2. Run clean sed edits to append components safely only if they don't already exist on that line
        sudo sed -i -E '/^deb(-src)?\s+/ { /contrib/!s/\bmain\b/main contrib/ }' /etc/apt/sources.list
        sudo sed -i -E '/^deb(-src)?\s+/ { /non-free /!s/\bmain\b/main non-free/ }' /etc/apt/sources.list
        sudo sed -i -E '/^deb(-src)?\s+/ { /non-free-firmware/!s/\bmain\b/main non-free-firmware/ }' /etc/apt/sources.list
        
        echo -e "${GREEN}✅ Successfully updated /etc/apt/sources.list! Backup saved as sources.list.bak${NC}"
    else
        echo -e "${YELLOW}⏭️  Keeping current repository components untouched.${NC}"
    fi
else
    echo -e "${GREEN}✅ Repositories already include contrib, non-free, and non-free-firmware.${NC}"
fi
sleep 2

# ----------------------------------------------------------------------
# 4. Perform system update and upgrade
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 🔄 Updating package lists and upgrading packages ===${NC}"
sudo apt-get update
sudo apt-get upgrade -y
echo -e "${GREEN}✅ System update and upgrade completed successfully!${NC}"
echo ""
read -r -p "Press [Enter] to proceed to package manager configuration..."

# ----------------------------------------------------------------------
# 5. Optional: Package Manager Selection (Apt vs Nala)
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
