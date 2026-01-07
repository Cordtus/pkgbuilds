#!/bin/bash
# Garuda Linux Desktop Environment Selector
# Command-line tool for managing DE selection

set -e

CONFIG_FILE="/etc/garuda/de-selector.conf"
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo -e "${RED}Error: Configuration file not found at $CONFIG_FILE${NC}" >&2
        exit 1
    fi
}

# Print usage information
usage() {
    cat << EOF
Garuda Linux Desktop Environment Selector v${VERSION}

Usage: garuda-de-selector [COMMAND] [OPTIONS]

Commands:
    list            List all available desktop environments
    current         Show currently active/selected DE
    set <DE>        Set the default desktop environment
    boot-select <DE> Set DE for next boot only
    enable <DE>     Enable a DE in the boot menu
    disable <DE>    Disable a DE from the boot menu
    update-grub     Regenerate GRUB configuration
    status          Show current configuration status
    help            Show this help message

Desktop Environments:
    kde, gnome, xfce, cinnamon, mate, hyprland, sway, wayfire, i3, qtile, lxqt, cosmic

Examples:
    garuda-de-selector list
    garuda-de-selector set kde
    garuda-de-selector boot-select gnome

EOF
}

# Get display name for DE
get_de_display_name() {
    case "$1" in
        kde)      echo "KDE Plasma" ;;
        gnome)    echo "GNOME" ;;
        xfce)     echo "XFCE" ;;
        cinnamon) echo "Cinnamon" ;;
        mate)     echo "MATE" ;;
        hyprland) echo "Hyprland (Wayland)" ;;
        sway)     echo "Sway (Wayland)" ;;
        wayfire)  echo "Wayfire (Wayland)" ;;
        i3)       echo "i3 Window Manager" ;;
        qtile)    echo "Qtile" ;;
        lxqt)     echo "LXQt" ;;
        cosmic)   echo "COSMIC" ;;
        *)        echo "$1" ;;
    esac
}

# Check if a DE is installed
is_de_installed() {
    local de="$1"
    local session_var="DE_SESSION_${de^^}"
    local session_name="${!session_var}"

    if [[ -z "$session_name" ]]; then
        return 1
    fi

    if [[ -f "/usr/share/xsessions/${session_name}.desktop" ]] || \
       [[ -f "/usr/share/wayland-sessions/${session_name}.desktop" ]]; then
        return 0
    fi
    return 1
}

# List available DEs
cmd_list() {
    echo -e "${BLUE}Available Desktop Environments:${NC}"
    echo ""

    local all_des="kde gnome xfce cinnamon mate hyprland sway wayfire i3 qtile lxqt cosmic"

    for de in $all_des; do
        local name
        name=$(get_de_display_name "$de")
        local status=""

        if is_de_installed "$de"; then
            status="${GREEN}[installed]${NC}"
        else
            status="${YELLOW}[not installed]${NC}"
        fi

        # Check if enabled in boot menu
        if [[ "$ENABLED_DES" == *"$de"* ]]; then
            status="$status ${BLUE}[boot menu]${NC}"
        fi

        # Check if default
        if [[ "$DEFAULT_DE" == "$de" ]]; then
            status="$status ${GREEN}[default]${NC}"
        fi

        printf "  %-12s %-25s %b\n" "$de" "$name" "$status"
    done
}

# Show current DE
cmd_current() {
    echo -e "${BLUE}Current Configuration:${NC}"
    echo ""

    # Check boot parameter
    local boot_de
    boot_de=$(cat /proc/cmdline 2>/dev/null | grep -oP "${BOOT_PARAM}=\K\w+" || true)

    if [[ -n "$boot_de" ]]; then
        echo -e "  Boot selection:  ${GREEN}$(get_de_display_name "$boot_de")${NC} ($boot_de)"
    fi

    echo -e "  Default DE:      ${GREEN}$(get_de_display_name "$DEFAULT_DE")${NC} ($DEFAULT_DE)"

    # Check last boot file
    if [[ -f "$LAST_BOOT_FILE" ]]; then
        local last_boot
        last_boot=$(cat "$LAST_BOOT_FILE")
        echo -e "  Last boot:       $(get_de_display_name "$last_boot") ($last_boot)"
    fi

    # Try to detect running session
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        echo -e "  Running session: ${GREEN}$XDG_CURRENT_DESKTOP${NC}"
    fi
}

# Set default DE
cmd_set() {
    local de="$1"

    if [[ -z "$de" ]]; then
        echo -e "${RED}Error: Please specify a desktop environment${NC}" >&2
        usage
        exit 1
    fi

    de=$(echo "$de" | tr '[:upper:]' '[:lower:]')

    if ! is_de_installed "$de"; then
        echo -e "${RED}Error: $de is not installed${NC}" >&2
        echo "Install it first or choose an installed DE."
        exit 1
    fi

    # Update configuration
    if [[ -w "$CONFIG_FILE" ]] || [[ $EUID -eq 0 ]]; then
        sed -i "s/^DEFAULT_DE=.*/DEFAULT_DE=$de/" "$CONFIG_FILE"
        echo -e "${GREEN}Default desktop environment set to: $(get_de_display_name "$de")${NC}"

        echo ""
        echo "To apply changes to GRUB menu, run:"
        echo "  sudo update-grub"
    else
        echo -e "${RED}Error: Permission denied. Run with sudo.${NC}" >&2
        exit 1
    fi
}

# Set DE for next boot only
cmd_boot_select() {
    local de="$1"

    if [[ -z "$de" ]]; then
        echo -e "${RED}Error: Please specify a desktop environment${NC}" >&2
        exit 1
    fi

    de=$(echo "$de" | tr '[:upper:]' '[:lower:]')

    if ! is_de_installed "$de"; then
        echo -e "${RED}Error: $de is not installed${NC}" >&2
        exit 1
    fi

    # Store selection for next boot
    local state_dir
    state_dir=$(dirname "$LAST_BOOT_FILE")

    if [[ ! -d "$state_dir" ]]; then
        sudo mkdir -p "$state_dir"
    fi

    echo "$de" | sudo tee "$LAST_BOOT_FILE" > /dev/null
    echo -e "${GREEN}Next boot will use: $(get_de_display_name "$de")${NC}"
}

# Enable DE in boot menu
cmd_enable() {
    local de="$1"

    if [[ -z "$de" ]]; then
        echo -e "${RED}Error: Please specify a desktop environment${NC}" >&2
        exit 1
    fi

    de=$(echo "$de" | tr '[:upper:]' '[:lower:]')

    if [[ "$ENABLED_DES" == *"$de"* ]]; then
        echo -e "${YELLOW}$de is already enabled in boot menu${NC}"
        return
    fi

    local new_enabled="${ENABLED_DES},$de"
    sed -i "s/^ENABLED_DES=.*/ENABLED_DES=\"$new_enabled\"/" "$CONFIG_FILE"
    echo -e "${GREEN}Enabled $de in boot menu${NC}"
    echo "Run 'sudo update-grub' to apply changes."
}

# Disable DE in boot menu
cmd_disable() {
    local de="$1"

    if [[ -z "$de" ]]; then
        echo -e "${RED}Error: Please specify a desktop environment${NC}" >&2
        exit 1
    fi

    de=$(echo "$de" | tr '[:upper:]' '[:lower:]')

    local new_enabled
    new_enabled=$(echo "$ENABLED_DES" | sed "s/,$de//g" | sed "s/$de,//g" | sed "s/$de//g")
    sed -i "s/^ENABLED_DES=.*/ENABLED_DES=\"$new_enabled\"/" "$CONFIG_FILE"
    echo -e "${GREEN}Disabled $de in boot menu${NC}"
    echo "Run 'sudo update-grub' to apply changes."
}

# Update GRUB
cmd_update_grub() {
    echo -e "${BLUE}Updating GRUB configuration...${NC}"
    if command -v update-grub &> /dev/null; then
        sudo update-grub
    elif command -v grub-mkconfig &> /dev/null; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo -e "${RED}Error: Could not find grub-mkconfig or update-grub${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}GRUB configuration updated!${NC}"
}

# Show status
cmd_status() {
    echo -e "${BLUE}Garuda DE Selector Status${NC}"
    echo ""
    echo "Configuration file: $CONFIG_FILE"
    echo ""
    echo "Settings:"
    echo "  Boot menu enabled:  $GRUB_DE_SELECTION_ENABLED"
    echo "  Default DE:         $DEFAULT_DE"
    echo "  Display manager:    $DISPLAY_MANAGER"
    echo "  Remember selection: $REMEMBER_LAST_BOOT"
    echo ""
    echo "Enabled DEs: $ENABLED_DES"
}

# Main
main() {
    load_config

    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        list)
            cmd_list
            ;;
        current)
            cmd_current
            ;;
        set)
            cmd_set "$@"
            ;;
        boot-select)
            cmd_boot_select "$@"
            ;;
        enable)
            cmd_enable "$@"
            ;;
        disable)
            cmd_disable "$@"
            ;;
        update-grub)
            cmd_update_grub
            ;;
        status)
            cmd_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
