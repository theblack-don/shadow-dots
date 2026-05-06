#!/usr/bin/env bash
# install.sh - Shadow Dots Installer for CachyOS/Arch
# Installs DCLI, copies the shadow-hypr module, and runs initial sync

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_SRC="${REPO_DIR}/arch-config/modules/shadow-hypr"
MODULE_DEST="${HOME}/.config/arch-config/modules/shadow-hypr"

#######################################
# Colors
#######################################
red()     { echo -e "\033[0;31m$*\033[0m"; }
green()   { echo -e "\033[0;32m$*\033[0m"; }
cyan()    { echo -e "\033[0;36m$*\033[0m"; }
yellow()  { echo -e "\033[1;33m$*\033[0m"; }

#######################################
# Detect AUR helper
#######################################
detect_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo ""
    fi
}

#######################################
# Main
#######################################
main() {
    echo ""
    cyan "╔═══════════════════════════════════════════════╗"
    cyan "║     Shadow Dots Installer                     ║"
    cyan "║     Hyprland + DMS/Noctalia via DCLI          ║"
    cyan "╚═══════════════════════════════════════════════╝"
    echo ""

    # 1. Detect AUR helper
    local aur_helper
    aur_helper=$(detect_aur_helper)
    if [[ -z "$aur_helper" ]]; then
        red "No AUR helper found (yay or paru required)"
        exit 1
    fi
    green "Found AUR helper: $aur_helper"

    # 2. Install dcli if missing
    if ! command -v dcli &>/dev/null; then
        yellow "dcli not found. Installing dcli-arch-git..."
        $aur_helper -S --needed dcli-arch-git
        hash -r
    else
        green "dcli is already installed"
    fi

    # 3. Initialize dcli config if needed
    if [[ ! -d "${HOME}/.config/arch-config" ]]; then
        yellow "Initializing DCLI config..."
        dcli init -b
    else
        green "DCLI config already initialized"
    fi

    # 4. Copy module
    cyan "Copying shadow-hypr module..."
    rm -rf "$MODULE_DEST"
    mkdir -p "$(dirname "$MODULE_DEST")"
    cp -r "$MODULE_SRC" "$MODULE_DEST"
    green "Module copied to ${MODULE_DEST}"

    # 5. Enable module
    cyan "Enabling shadow-hypr module..."
    dcli module enable shadow-hypr

    # 6. Sync
    echo ""
    cyan "Running dcli sync (this may take a while)..."
    dcli sync

    echo ""
    green "╔═══════════════════════════════════════════════╗"
    green "║     Installation Complete!                    ║"
    green "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and select Hyprland from your display manager."
    echo "  2. Noctalia Shell will start automatically."
    echo "  3. Press Super+Space to open the launcher."
    echo "  4. Run 'shell-switch' in a terminal to switch to DMS."
    echo ""
}

main "$@"
