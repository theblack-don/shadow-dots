#!/usr/bin/env bash
# shell-switch.sh - Interactive TUI for switching between DMS and Noctalia on Hyprland
# Self-contained, bundled with shadow-hypr module

set -euo pipefail

SHELL_SWITCH_DIR="${HOME}/.config/shell-switch"
CONFIG_FILE="${SHELL_SWITCH_DIR}/config.json"

#######################################
# Colors and icons
#######################################
red() { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
cyan() { echo -e "\033[0;36m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

ICON_ACTIVE="●"
ICON_INACTIVE="○"

#######################################
# Log to file
#######################################
log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] [${level}] ${msg}" >> "${SHELL_SWITCH_DIR}/shell-switch.log"
}

#######################################
# Shell database
#######################################
init_shell_db() {
    declare -gA SHELL_NAME SHELL_LAUNCH SHELL_LAUNCHER SHELL_PATTERN
    SHELL_NAME[noctalia]="Noctalia Shell"
    SHELL_NAME[dms]="Dank Material Shell"
    SHELL_LAUNCH[noctalia]="qs -c noctalia-shell"
    SHELL_LAUNCH[dms]="dms run"
    SHELL_LAUNCHER[noctalia]="qs -c noctalia-shell ipc call launcher toggle"
    SHELL_LAUNCHER[dms]="dms ipc call spotlight toggle"
    SHELL_PATTERN[noctalia]="qs.*noctalia-shell"
    SHELL_PATTERN[dms]="dms run"
}

#######################################
# Load current shell from config.json
#######################################
load_current_shell() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        red "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    jq -r '.current_shell' "$CONFIG_FILE"
}

#######################################
# Save current shell to config.json
#######################################
save_current_shell() {
    local shell_id="$1"
    local tmp
    tmp=$(mktemp)
    jq --arg shell "$shell_id" \
       --arg ts "$(date -Iseconds)" \
       '.current_shell = $shell | .last_switch = $ts | .switch_count += 1' \
       "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    log "INFO" "Updated config: current_shell=$shell_id"
}

#######################################
# Check if a shell is running
#######################################
is_shell_running() {
    local pattern="$1"
    pgrep -f "$pattern" &>/dev/null
}

#######################################
# Stop a shell
#######################################
stop_shell() {
    local pattern="$1"
    local name="$2"

    if ! is_shell_running "$pattern"; then
        log "INFO" "$name is not running"
        return 0
    fi

    cyan "Stopping $name..."
    pkill -f "$pattern" || true

    local timeout=5
    while [[ $timeout -gt 0 ]]; do
        if ! is_shell_running "$pattern"; then
            green "Stopped $name"
            return 0
        fi
        sleep 0.5
        ((timeout--))
    done

    yellow "$name did not stop gracefully, forcing..."
    pkill -9 -f "$pattern" || true
    sleep 0.5

    if ! is_shell_running "$pattern"; then
        green "Stopped $name (forced)"
        return 0
    fi

    red "Failed to stop $name"
    return 1
}

#######################################
# Start a shell
#######################################
start_shell() {
    local cmd="$1"
    local name="$2"
    cyan "Starting $name..."
    eval "$cmd" &>/dev/null &
    sleep 1
}

#######################################
# Verify shell is running
#######################################
verify_shell() {
    local pattern="$1"
    local name="$2"
    local timeout="${3:-5}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if is_shell_running "$pattern"; then
            green "$name is running"
            return 0
        fi
        sleep 0.5
        ((elapsed++))
    done

    red "$name failed to start within ${timeout}s"
    return 1
}

#######################################
# Generate Hyprland startup include
#######################################
generate_startup_include() {
    local shell_id="$1"
    local launch_cmd="${SHELL_LAUNCH[$shell_id]}"
    local shell_name="${SHELL_NAME[$shell_id]}"

    cat > "${HOME}/.config/hypr/shell-switcher-startup.conf" <<EOF
# Shell Switcher - Startup Configuration
# This file is managed by shell-switch - manual edits will be overwritten
# Current shell: ${shell_name}

exec-once = ${launch_cmd}
EOF
}

#######################################
# Generate Hyprland binds include
#######################################
generate_binds_include() {
    local shell_id="$1"
    local launcher_cmd="${SHELL_LAUNCHER[$shell_id]}"
    local shell_name="${SHELL_NAME[$shell_id]}"

    cat > "${HOME}/.config/hypr/shell-switcher-binds.conf" <<EOF
# Shell Switcher - Keybindings
# This file is managed by shell-switch for the switcher and launcher bindings
# Current shell: ${shell_name}
# You can add additional shell-specific keybindings below the managed section

# === MANAGED BY SHELL-SWITCH - DO NOT EDIT THIS SECTION ===

# App Launcher for ${shell_name}
bind = SUPER, Space, exec, ${launcher_cmd}

# === END MANAGED SECTION ===

# Add your custom shell-specific keybindings below:
EOF
}

#######################################
# Reload Hyprland config
#######################################
reload_hyprland() {
    cyan "Reloading Hyprland..."
    if command -v hyprctl &>/dev/null; then
        hyprctl reload &>/dev/null || true
        green "Hyprland reloaded"
    else
        yellow "hyprctl not found, skipping reload"
    fi
}

#######################################
# Build fzf menu
#######################################
build_menu() {
    local current="$1"
    for shell in noctalia dms; do
        if [[ "$shell" == "$current" ]]; then
            echo "${ICON_ACTIVE} ${SHELL_NAME[$shell]} (active)|${shell}"
        else
            echo "${ICON_INACTIVE} ${SHELL_NAME[$shell]}|${shell}"
        fi
    done
}

#######################################
# Show TUI and get selection
#######################################
show_tui() {
    local current="$1"
    if ! command -v fzf &>/dev/null; then
        red "fzf is not installed"
        exit 1
    fi

    local menu
    menu=$(build_menu "$current")

    local selected
    selected=$(echo "$menu" | fzf \
        --prompt="Select shell: " \
        --height=40% \
        --border=rounded \
        --reverse \
        --ansi \
        --no-info \
        --delimiter='|' \
        --with-nth=1 \
        --header="Compositor: hyprland")

    if [[ -z "$selected" ]]; then
        log "INFO" "User cancelled shell selection"
        exit 0
    fi

    echo "$selected" | cut -d'|' -f2
}

#######################################
# Main switching logic
#######################################
main() {
    log "INFO" "=== Shell Switcher Started ==="
    init_shell_db

    if ! command -v jq &>/dev/null; then
        red "jq is not installed"
        exit 1
    fi

    local current_shell
    current_shell=$(load_current_shell)
    local current_name="${SHELL_NAME[$current_shell]}"

    echo ""
    cyan "Current shell: $current_name"
    echo ""

    local new_shell
    new_shell=$(show_tui "$current_shell")

    if [[ "$new_shell" == "$current_shell" ]]; then
        cyan "$current_name is already active"
        exit 0
    fi

    local new_name="${SHELL_NAME[$new_shell]}"
    echo ""
    cyan "Switching from $current_name to $new_name..."
    echo ""

    # Generate new compositor includes BEFORE switching
    generate_startup_include "$new_shell"
    generate_binds_include "$new_shell"

    # Stop current shell
    if ! stop_shell "${SHELL_PATTERN[$current_shell]}" "$current_name"; then
        red "Failed to stop $current_name"
        exit 1
    fi

    # Start new shell
    start_shell "${SHELL_LAUNCH[$new_shell]}" "$new_name"

    # Verify new shell started
    if ! verify_shell "${SHELL_PATTERN[$new_shell]}" "$new_name"; then
        red "Shell switch failed"
        yellow "Attempting to rollback to $current_name..."
        generate_startup_include "$current_shell"
        generate_binds_include "$current_shell"
        start_shell "${SHELL_LAUNCH[$current_shell]}" "$current_name"
        if verify_shell "${SHELL_PATTERN[$current_shell]}" "$current_name" 5; then
            yellow "Rolled back to $current_name"
        else
            red "CRITICAL: Rollback failed!"
        fi
        exit 1
    fi

    # Save state
    save_current_shell "$new_shell"

    # Reload compositor
    reload_hyprland

    echo ""
    green "Successfully switched to $new_name!"
    log "INFO" "=== Shell Switcher Completed ==="
}

main "$@"
