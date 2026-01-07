#!/bin/bash
# Garuda Linux Desktop Environment Boot Application Script
# This script runs at boot to apply the DE selection from GRUB

CONFIG_FILE="/etc/garuda/de-selector.conf"
LOG_FILE="/var/log/garuda-de-selector.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Source configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log "ERROR: Configuration file not found"
    exit 0
fi

# Get DE selection from boot parameters
get_boot_de() {
    local cmdline
    cmdline=$(cat /proc/cmdline)
    echo "$cmdline" | grep -oP "${BOOT_PARAM}=\K\w+" || echo ""
}

# Get session file path for a DE
get_session_file() {
    local de="$1"
    local session_var="DE_SESSION_${de^^}"
    local session_name="${!session_var}"

    if [[ -z "$session_name" ]]; then
        echo ""
        return
    fi

    # Check Wayland first, then X11
    if [[ -f "/usr/share/wayland-sessions/${session_name}.desktop" ]]; then
        echo "/usr/share/wayland-sessions/${session_name}.desktop"
    elif [[ -f "/usr/share/xsessions/${session_name}.desktop" ]]; then
        echo "/usr/share/xsessions/${session_name}.desktop"
    else
        echo ""
    fi
}

# Configure SDDM to use selected session
configure_sddm() {
    local session_file="$1"
    local session_name
    session_name=$(basename "$session_file" .desktop)

    local sddm_state_dir="/var/lib/sddm"
    local sddm_state_file="$sddm_state_dir/state.conf"

    # Create state directory if needed
    mkdir -p "$sddm_state_dir"

    # Determine session type
    local session_type="x11"
    if [[ "$session_file" == *"wayland-sessions"* ]]; then
        session_type="wayland"
    fi

    # Write SDDM state file to preselect the session
    cat > "$sddm_state_file" << EOF
[Last]
Session=$session_file
EOF

    log "Configured SDDM to use session: $session_name ($session_type)"
}

# Configure LightDM
configure_lightdm() {
    local session_file="$1"
    local session_name
    session_name=$(basename "$session_file" .desktop)

    local lightdm_conf="/etc/lightdm/lightdm.conf.d/50-de-selector.conf"

    mkdir -p "$(dirname "$lightdm_conf")"

    cat > "$lightdm_conf" << EOF
[Seat:*]
user-session=$session_name
EOF

    log "Configured LightDM to use session: $session_name"
}

# Configure GDM
configure_gdm() {
    local session_file="$1"
    local session_name
    session_name=$(basename "$session_file" .desktop)

    # GDM uses AccountsService to store session preference
    # We'll set it for all users in /var/lib/AccountsService/users/
    local accounts_dir="/var/lib/AccountsService/users"

    if [[ -d "$accounts_dir" ]]; then
        for user_file in "$accounts_dir"/*; do
            if [[ -f "$user_file" ]]; then
                local username
                username=$(basename "$user_file")
                # Skip system users
                local uid
                uid=$(id -u "$username" 2>/dev/null || echo "0")
                if [[ "$uid" -ge 1000 ]]; then
                    # Update or add XSession
                    if grep -q "^XSession=" "$user_file"; then
                        sed -i "s/^XSession=.*/XSession=$session_name/" "$user_file"
                    else
                        echo "XSession=$session_name" >> "$user_file"
                    fi
                    log "Configured GDM session for user $username: $session_name"
                fi
            fi
        done
    fi
}

# Save last boot selection
save_last_boot() {
    local de="$1"
    if [[ "$REMEMBER_LAST_BOOT" == "yes" ]]; then
        local state_dir
        state_dir=$(dirname "$LAST_BOOT_FILE")
        mkdir -p "$state_dir"
        echo "$de" > "$LAST_BOOT_FILE"
        log "Saved last boot selection: $de"
    fi
}

# Main
main() {
    log "Starting DE selection application"

    # Get the selected DE from boot parameters
    local selected_de
    selected_de=$(get_boot_de)

    # Fall back to last boot selection if configured
    if [[ -z "$selected_de" ]] && [[ "$REMEMBER_LAST_BOOT" == "yes" ]] && [[ -f "$LAST_BOOT_FILE" ]]; then
        selected_de=$(cat "$LAST_BOOT_FILE")
        log "Using last boot selection: $selected_de"
    fi

    # Fall back to default if still nothing
    if [[ -z "$selected_de" ]]; then
        selected_de="$DEFAULT_DE"
        log "Using default DE: $selected_de"
    fi

    log "Selected DE: $selected_de"

    # Get the session file
    local session_file
    session_file=$(get_session_file "$selected_de")

    if [[ -z "$session_file" ]]; then
        log "ERROR: Could not find session file for $selected_de"
        exit 0
    fi

    log "Session file: $session_file"

    # Configure the appropriate display manager
    case "$DISPLAY_MANAGER" in
        sddm)
            configure_sddm "$session_file"
            ;;
        lightdm)
            configure_lightdm "$session_file"
            ;;
        gdm)
            configure_gdm "$session_file"
            ;;
        *)
            log "Unknown display manager: $DISPLAY_MANAGER"
            # Try to configure SDDM as fallback
            configure_sddm "$session_file"
            ;;
    esac

    # Save the selection
    save_last_boot "$selected_de"

    log "DE selection application complete"
}

main "$@"
