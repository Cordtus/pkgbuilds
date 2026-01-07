Garuda Linux Test-Drive Edition
================================

Welcome to Garuda Linux Test-Drive! This edition allows you to experience
multiple desktop environments on a single installation.

INCLUDED DESKTOP ENVIRONMENTS
-----------------------------
- KDE Plasma    : Modern, feature-rich desktop with extensive customization
- GNOME         : Clean, elegant desktop focused on simplicity
- XFCE          : Lightweight, fast, and highly customizable

ADDITIONAL DEs (can be installed separately)
--------------------------------------------
- Cinnamon      : Traditional desktop with modern features
- MATE          : Classic GNOME 2 fork
- Hyprland      : Dynamic tiling Wayland compositor
- Sway          : i3-compatible Wayland compositor
- Wayfire       : 3D Wayland compositor
- i3            : Tiling window manager
- Qtile         : Tiling WM written in Python
- LXQt          : Lightweight Qt desktop

HOW TO SELECT A DESKTOP ENVIRONMENT
-----------------------------------

Method 1: At the Login Screen (SDDM)
  - Click on your username
  - Look for a session selector (gear icon or dropdown)
  - Select your preferred desktop environment
  - Enter your password and log in

Method 2: At Boot Time (GRUB Menu)
  - When your computer starts, the GRUB boot menu will appear
  - Select "Garuda Linux - Desktop Environment Selection"
  - Choose your preferred desktop environment
  - The system will boot directly into that DE

Method 3: Command Line
  Use the garuda-de-selector command:

  $ garuda-de-selector list          # List available DEs
  $ garuda-de-selector current       # Show current DE
  $ garuda-de-selector set kde       # Set default DE to KDE
  $ garuda-de-selector set gnome     # Set default DE to GNOME
  $ sudo update-grub                 # Update GRUB menu after changes

INSTALLING ADDITIONAL DEs
-------------------------
You can install additional desktop environments:

  $ sudo pacman -S cinnamon           # Install Cinnamon
  $ sudo pacman -S mate mate-extra    # Install MATE
  $ sudo pacman -S hyprland waybar    # Install Hyprland
  $ sudo pacman -S sway               # Install Sway

After installing, run:
  $ garuda-de-selector enable <de>    # Add to boot menu
  $ sudo update-grub                  # Update GRUB

TIPS
----
- Each DE has its own settings and customizations
- Your files and applications work across all DEs
- Some DEs may have different default applications
- Wayland DEs (Hyprland, Sway, GNOME Wayland) offer better security
- X11 DEs offer better compatibility with older applications

TROUBLESHOOTING
---------------
If a DE doesn't start:
1. Try logging out and selecting a different DE
2. Check ~/.local/share/xorg/ for X11 logs
3. Check journalctl -xe for systemd logs
4. Ensure all required packages are installed

For support, visit: https://forum.garudalinux.org

Enjoy exploring different desktop environments!
