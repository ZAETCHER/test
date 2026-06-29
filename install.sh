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

    echo -e -n "${CYAN}${prompt} ${YELLOW}[Y/n]: ${NC}"
    read -r answer

    case "$answer" in
        [Nn]*) return 1 ;;
        *)     return 0 ;;
    esac
}

# ----------------------------------------------------------------------
# Helper: Package Selection UI
# ----------------------------------------------------------------------
handle_de_selection() {
    local -n pkgs=$1
    local -n desc=$2

    clear
    echo -e "${BLUE}=== 🖥️  Select Packages to Install ===${NC}"
    echo -e "Choose the packages you want in your custom build.\n"

    # Dynamically print the numbered list – FIXED: no variables in format string
    for i in "${!pkgs[@]}"; do
        printf "%s%2d%s %s%-20s%s - %s\n" \
            "${CYAN}" "$((i+1))" "${NC}" \
            "${GREEN}" "${pkgs[$i]}" "${NC}" \
            "${desc[$i]}"
    done

    echo ""
    echo -e "${YELLOW}Enter the numbers of the packages you want to install, separated by spaces.${NC}"
    echo -e "${YELLOW}(Example: 1 2 4 5 7)${NC}"

    local -a user_array
    IFS=' ' read -r -p "> " -a user_array

    local -a selected_packages=()
    local display_packages=""

    for num in "${user_array[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            local idx=$((num-1))
            if [[ -n "${pkgs[$idx]:-}" ]]; then
                selected_packages+=( "${pkgs[$idx]}" )
                display_packages+="\n  - ${pkgs[$idx]}"
            fi
        fi
    done

    if [[ ${#selected_packages[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No valid packages selected. Skipping DE installation.${NC}"
        sleep 2
        return
    fi

    clear
    echo -e "${BLUE}=== 📝 Verification ===${NC}"
    echo -e "You have selected the following packages to install via ${YELLOW}${PKG_MGR}${NC}:"
    echo -e "${GREEN}${display_packages}${NC}"
    echo ""

    if prompt_yes_no "❓ Do you want to proceed and install these packages now?"; then
        echo -e "${GREEN}📥 Installing selected packages...${NC}"
        sudo "$PKG_MGR" install -y "${selected_packages[@]}"
        echo -e "${GREEN}✅ Desktop Environment installation complete!${NC}"
    else
        echo -e "${YELLOW}⏭️  Installation aborted by user.${NC}"
    fi
    sleep 2
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
            # FIXED: properly expand $USER inside the su command
            su -c "apt-get update && apt-get install -y sudo && /usr/sbin/usermod -aG sudo \"$USER\""

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
# 2. Verify sudo privileges
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
# 3. Check and Configure Debian Repositories
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 📋 Checking Repository Components ===${NC}"
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
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
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
# 5. Package Manager Selection
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 📦 Package Manager Enhancement Selection ===${NC}"
echo -e "By default, Debian uses ${CYAN}apt${NC}. However, you can upgrade to ${GREEN}nala${NC}."
echo -e ""
if prompt_yes_no "❓ Do you want to install Nala and use it for subsequent installations?"; then
    if command -v nala &>/dev/null; then
        echo -e "${YELLOW}📦 nala is already installed on this system.${NC}"
    else
        echo -e "${GREEN}📥 Installing nala...${NC}"
        sudo apt-get install -y nala
        echo -e "${GREEN}✅ nala installed successfully.${NC}"
    fi
    PKG_MGR="nala"
else
    echo -e "${YELLOW}⏭️  Skipping Nala. Staying with default standard 'apt'.${NC}"
    PKG_MGR="apt"
fi
sleep 1

# ----------------------------------------------------------------------
# 6. Desktop Environment Configuration & Installation
# ----------------------------------------------------------------------
clear
echo -e "${BLUE}=== 🖥️  Desktop Environment (DE) Selection ===${NC}"
echo -e "Choose a minimal Desktop Environment to install:"
echo -e "  ${CYAN}1)${NC} KDE Minimal"
echo -e "  ${CYAN}2)${NC} KDE Ultra Minimal (Only if you know what you're doing)"
echo -e "  ${CYAN}3)${NC} GNOME Minimal"
echo -e "  ${CYAN}4)${NC} GNOME Ultra Minimal"
echo -e "  ${CYAN}5)${NC} Skip DE Installation"
echo ""

read -r -p "Select an option [1-5]: " de_choice

case "$de_choice" in
    1)
        pkgs=( "kde-plasma-desktop" "plasma-nm" "sddm-theme-breeze" "kwin-addons" "firefox-esr" "synaptic" "vlc" "kdeconnect" "neovim" "btop" "fastfetch" "kcalc" "ark" "gwenview" )
        desc=( "Core Plasma desktop environment" "Network Manager integration" "Breeze theme for SDDM" "Additional KWin effects" "Firefox browser" "Graphical package manager" "Media player" "Phone integration" "Text editor (Vim-fork)" "Resource monitor" "System info fetcher" "Calculator" "Archive manager" "Image viewer" )
        handle_de_selection pkgs desc
        ;;
    2)
        pkgs=( "plasma-desktop" "sddm" "firefox-esr" "vlc" "plasma-nm" )
        desc=( "Absolute barebones Plasma desktop" "Display manager / login screen" "Firefox browser" "Media player" "Network Manager integration" )
        handle_de_selection pkgs desc
        ;;
    3)
        pkgs=( "gnome-core" "network-manager-gnome" "gdm3" "firefox-esr" "gnome-tweaks" )
        desc=( "Core GNOME desktop environment" "Network Manager applet" "GNOME display manager" "Firefox browser" "GNOME customization tool" )
        handle_de_selection pkgs desc
        ;;
    4)
        pkgs=( "gnome-session" "mutter" "gdm3" "gnome-terminal" "firefox-esr" )
        desc=( "Absolute barebones GNOME session" "GNOME window manager" "GNOME display manager" "Terminal emulator" "Firefox browser" )
        handle_de_selection pkgs desc
        ;;
    *)
        echo -e "${YELLOW}⏭️  Skipping Desktop Environment installation.${NC}"
        sleep 1
        ;;
esac

# ----------------------------------------------------------------------
# Final Status Screen
# ----------------------------------------------------------------------
clear
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}🎉   System initialization completed!         🎉${NC}"
echo -e "${GREEN}===============================================${NC}"
echo -e " Preferred Package Manager: ${GREEN}${PKG_MGR}${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
