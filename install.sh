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
# Global Variables
# ----------------------------------------------------------------------
PKG_MGR="apt" 

# ----------------------------------------------------------------------
# Helper: Prompt with default Yes (Enter = Yes)
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
    # Using unique names for namerefs to avoid circular reference
    local -n ref_pkgs=$1
    local -n ref_desc=$2
    
    clear
    echo -e "${BLUE}=== 🖥️  Select Packages to Install ===${NC}"
    echo -e "Choose the packages you want in your custom build.\n"
    
    for i in "${!ref_pkgs[@]}"; do
        printf "  ${CYAN}%2d)${NC} ${GREEN}%-20s${NC} - %s\n" "$((i+1))" "${ref_pkgs[$i]}" "${ref_desc[$i]}"
    done
    
    echo ""
    echo -e "${YELLOW}Enter the numbers of the packages you want to install, separated by spaces.${NC}"
    
    local -a user_array
    read -r -p "> " -a user_array
    
    local -a selected_packages=()
    local display_packages=""
    
    for num in "${user_array[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            local idx=$((num-1))
            if [[ -n "${ref_pkgs[$idx]:-}" ]]; then
                selected_packages+=( "${ref_pkgs[$idx]}" )
                display_packages+="\n  - ${ref_pkgs[$idx]}"
            fi
        fi
    done
    
    if [[ ${#selected_packages[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No valid packages selected.${NC}"
        sleep 2
        return
    fi
    
    clear
    echo -e "${BLUE}=== 📝 Verification ===${NC}"
    echo -e "Selected packages to install via ${YELLOW}${PKG_MGR}${NC}:${GREEN}${display_packages}${NC}"
    echo ""
    
    if prompt_yes_no "❓ Proceed with installation?"; then
        echo -e "${GREEN}📥 Installing selected packages...${NC}"
        sudo "$PKG_MGR" install -y "${selected_packages[@]}"
        echo -e "${GREEN}✅ Installation complete!${NC}"
    fi
    sleep 2
}

# ----------------------------------------------------------------------
# WELCOME SCREEN
# ----------------------------------------------------------------------
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
echo -e "${YELLOW}⚡ WHAT?${NC} A zero-fuss script for a minimal desktop install on Debian 13."
echo -e "${YELLOW}⚡ WHY?${NC} Trims the fat; installs only the core components for a responsive system."
echo -e "${GREEN}======================================================================${NC}"
echo ""
read -r -p "Press [Enter] to start pre-flight environment checks..."

# 1. Sudo Check
if ! command -v sudo &>/dev/null; then
    if prompt_yes_no "❓ Sudo is missing. Install now?"; then
        su -c "apt-get update && apt-get install -y sudo && /usr/sbin/usermod -aG sudo '$USER'"
        echo -e "${YELLOW}⚠️ Please log out and back in to refresh sudo groups!${NC}"
        exit 0
    fi
fi

# 2. Repository Check
clear
echo -e "${BLUE}=== 📋 Checking Repository Components ===${NC}"
sudo sed -i -E '/^deb(-src)?\s+/ { /contrib/!s/\bmain\b/main contrib/ }' /etc/apt/sources.list
sudo sed -i -E '/^deb(-src)?\s+/ { /non-free /!s/\bmain\b/main non-free/ }' /etc/apt/sources.list
sudo sed -i -E '/^deb(-src)?\s+/ { /non-free-firmware/!s/\bmain\b/main non-free-firmware/ }' /etc/apt/sources.list
echo -e "${GREEN}✅ Repository components updated (contrib, non-free, non-free-firmware).${NC}"
sleep 1

# 3. Update & Upgrade
sudo apt-get update && sudo apt-get upgrade -y

# 4. Package Manager Selection
if prompt_yes_no "❓ Use Nala for installations (Faster, better UI)?"; then
    sudo apt-get install -y nala
    PKG_MGR="nala"
fi

# 5. DE Selection
clear
echo -e "${BLUE}=== 🖥️  Desktop Environment Selection ===${NC}"
echo -e "1) KDE Minimal\n2) KDE Ultra Minimal\n3) GNOME Minimal\n4) GNOME Ultra Minimal"
read -r -p "Select [1-4]: " de_choice

case "$de_choice" in
    1) pkgs=( "kde-plasma-desktop" "plasma-nm" "sddm-theme-breeze" "kwin-addons" "firefox-esr" "synaptic" "vlc" "kdeconnect" "neovim" "btop" "fastfetch" "kcalc" "ark" "gwenview" ); desc=( "Plasma" "NM" "Breeze" "Kwin" "Firefox" "Synaptic" "VLC" "Connect" "Nvim" "Btop" "Fetch" "Calc" "Ark" "Gwenview" ); handle_de_selection pkgs desc ;;
    2) pkgs=( "plasma-desktop" "sddm" "firefox-esr" "vlc" "plasma-nm" ); desc=( "Desktop" "SDDM" "Firefox" "VLC" "NM" ); handle_de_selection pkgs desc ;;
    3) pkgs=( "gnome-core" "network-manager-gnome" "gdm3" "firefox-esr" "gnome-tweaks" ); desc=( "Core" "NM" "GDM" "Firefox" "Tweaks" ); handle_de_selection pkgs desc ;;
    4) pkgs=( "gnome-session" "mutter" "gdm3" "gnome-terminal" "firefox-esr" ); desc=( "Session" "Mutter" "GDM" "Terminal" "Firefox" ); handle_de_selection pkgs desc ;;
esac

clear
echo -e "${GREEN}🎉 Initialization complete! Preferred Manager: ${PKG_MGR}${NC}"
