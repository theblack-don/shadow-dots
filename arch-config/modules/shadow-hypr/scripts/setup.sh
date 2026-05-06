#!/usr/bin/env bash
# setup.sh - Post-install hook for shadow-hypr module
# Sets up shell-switcher, generates Hyprland includes, creates default config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"

SHELL_SWITCH_DIR="${HOME}/.config/shell-switch"
HYPR_DIR="${HOME}/.config/hypr"
LOCAL_BIN="${HOME}/.local/bin"

#######################################
# Color helpers
#######################################
red() { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
cyan() { echo -e "\033[0;36m$*\033[0m"; }

#######################################
# Backup a file if it exists
#######################################
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        cp "$file" "${file}.${timestamp}.bak"
        echo "Backed up: $file"
    fi
}

#######################################
# Create shell-switch directory and copy script
#######################################
setup_shell_switch() {
    cyan "Setting up shell switcher..."
    mkdir -p "$SHELL_SWITCH_DIR"
    mkdir -p "$LOCAL_BIN"

    # Copy bundled switcher script
    cp "${SCRIPT_DIR}/shell-switch.sh" "${SHELL_SWITCH_DIR}/shell-switch.sh"
    chmod +x "${SHELL_SWITCH_DIR}/shell-switch.sh"

    # Symlink to PATH
    if [[ -L "${LOCAL_BIN}/shell-switch" ]]; then
        rm "${LOCAL_BIN}/shell-switch"
    fi
    ln -sf "${SHELL_SWITCH_DIR}/shell-switch.sh" "${LOCAL_BIN}/shell-switch"
    green "Shell switcher installed at ${LOCAL_BIN}/shell-switch"
}

#######################################
# Generate Hyprland startup include (Noctalia as default)
#######################################
generate_startup_include() {
    cyan "Generating Hyprland startup include..."
    cat > "${HYPR_DIR}/shell-switcher-startup.conf" <<'EOF'
# Shell Switcher - Startup Configuration
# This file is managed by shell-switch - manual edits will be overwritten
# Current shell: Noctalia Shell

exec-once = qs -c noctalia-shell
EOF
    green "Created: ${HYPR_DIR}/shell-switcher-startup.conf"
}

#######################################
# Generate Hyprland binds include
#######################################
generate_binds_include() {
    cyan "Generating Hyprland binds include..."
    cat > "${HYPR_DIR}/shell-switcher-binds.conf" <<'EOF'
# Shell Switcher - Keybindings
# This file is managed by shell-switch for the switcher and launcher bindings
# Current shell: Noctalia Shell
# You can add additional shell-specific keybindings below the managed section

# === MANAGED BY SHELL-SWITCH - DO NOT EDIT THIS SECTION ===

# App Launcher for Noctalia Shell
bind = SUPER, Space, exec, qs -c noctalia-shell ipc call launcher toggle

# === END MANAGED SECTION ===

# Add your custom shell-specific keybindings below:
EOF
    green "Created: ${HYPR_DIR}/shell-switcher-binds.conf"
}

#######################################
# Create shell-switch config.json
#######################################
create_switch_config() {
    cyan "Creating shell-switch config..."
    cat > "${SHELL_SWITCH_DIR}/config.json" <<EOF
{
  "version": "1.0",
  "current_shell": "noctalia",
  "compositor": "hyprland",
  "config_paths": {
    "hyprland": {
      "main": "${HOME}/.config/hypr/hyprland.conf",
      "startup": "${HOME}/.config/hypr/shell-switcher-startup.conf",
      "binds": "${HOME}/.config/hypr/shell-switcher-binds.conf"
    }
  },
  "shells": {
    "noctalia": {
      "name": "Noctalia Shell",
      "installed": true,
      "package": "noctalia-shell-git"
    },
    "dms": {
      "name": "Dank Material Shell",
      "installed": true,
      "package": "dms-shell-git"
    }
  },
  "last_switch": "$(date -Iseconds)",
  "switch_count": 0
}
EOF
    green "Created: ${SHELL_SWITCH_DIR}/config.json"
}

#######################################
# Main setup flow
#######################################
main() {
    echo ""
    cyan "=== Shadow Hyprland Post-Install Setup ==="
    echo ""

    mkdir -p "$HYPR_DIR"
    backup_if_exists "${HYPR_DIR}/shell-switcher-startup.conf"
    backup_if_exists "${HYPR_DIR}/shell-switcher-binds.conf"

    setup_shell_switch
    generate_startup_include
    generate_binds_include
    create_switch_config

    echo ""
    green "=== Setup complete! ==="
    echo ""
    echo "Default shell: Noctalia Shell"
    echo "Run 'shell-switch' to switch between Noctalia and DMS."
    echo ""
}

main "$@"
