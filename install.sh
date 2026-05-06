#!/usr/bin/env bash
# install.sh - Shadow Dots Installer for CachyOS/Arch
# Installs DCLI, copies the full arch-config, and runs initial sync

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${REPO_DIR}/arch-config"
CONFIG_DEST="${HOME}/.config/arch-config"

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
# Backup existing DCLI config
#######################################
backup_existing_config() {
    if [[ -d "$CONFIG_DEST" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_path="${CONFIG_DEST}.backup.${timestamp}"
        yellow "Existing DCLI config found. Backing up to ${backup_path}..."
        mv "$CONFIG_DEST" "$backup_path"
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

    # 3. Backup and copy full DCLI config
    backup_existing_config
    cyan "Copying DCLI config..."
    cp -r "$CONFIG_SRC" "$CONFIG_DEST"
    green "Config copied to ${CONFIG_DEST}"

    # 4. Update host name to match current hostname
    local hostname
    hostname=$(hostname)
    if [[ "$hostname" != "shadow" ]]; then
        yellow "Updating active host to match system hostname: ${hostname}..."
        sed -i "s/^active_host: shadow/active_host: ${hostname}/" "${CONFIG_DEST}/config.yaml"
        if [[ -f "${CONFIG_DEST}/hosts/shadow.yaml" ]]; then
            sed -i "s/^host: shadow/host: ${hostname}/" "${CONFIG_DEST}/hosts/shadow.yaml"
            mv "${CONFIG_DEST}/hosts/shadow.yaml" "${CONFIG_DEST}/hosts/${hostname}.yaml"
        fi
        green "Host updated to: ${hostname}"
    fi

    # 5. Validate config
    echo ""
    cyan "Validating DCLI config..."
    dcli validate

    echo ""
    green "╔═══════════════════════════════════════════════╗"
    green "║     Setup Complete!                           ║"
    green "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'dcli sync' to install packages and apply dotfiles."
    echo "  2. Log out and select Hyprland from your display manager."
    echo "  3. Noctalia Shell will start automatically."
    echo "  4. Press Super+Space to open the launcher."
    echo "  5. Run 'shell-switch' in a terminal to switch to DMS."
    echo ""
}

main "$@"
