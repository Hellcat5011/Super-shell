#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# 1. Sanity check: Ensure we are inside the cloned repo
if [ ! -d "$REPO_DIR/deploy" ] || [ ! -f "$REPO_DIR/shell.qml" ]; then
    echo "ERROR: Install script must be run from within the cloned repository."
    exit 1
fi

# 2. Copy live config (Excluding internal/dev artifacts)
echo "Copying live config to ~/.config/quickshell/xeon-shell..."
mkdir -p "$HOME/.config/quickshell/xeon-shell"
# Using rsync to cleanly exclude deploy/, scratch/, evidence/, and .git/
rsync -a --exclude 'deploy' --exclude 'scratch' --exclude 'evidence' --exclude '.git' "$REPO_DIR/" "$HOME/.config/quickshell/xeon-shell/"

# 3. Settings migration
OLD_CONF="$HOME/.config/Unknown Organization/quickshell.conf"
NEW_CONF_DIR="$HOME/.config/Xeon Shell"
NEW_CONF="$NEW_CONF_DIR/xeon-shell.conf"

if [ -f "$OLD_CONF" ]; then
    echo "Migrating old settings..."
    mkdir -p "$NEW_CONF_DIR"
    cp -n "$OLD_CONF" "$NEW_CONF" || true
fi

# 4. Privileged section
echo ""
echo "The next steps require root privileges to set up the greeter."
read -rp "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Validate sudo credentials once
sudo -v

# Keep-alive loop and cleanup
cleanup() {
    # Clean up the background sudo keep-alive process
    if [ -n "${KEEP_ALIVE_PID:-}" ]; then
        kill "$KEEP_ALIVE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Run keep-alive in background
(while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null) &
KEEP_ALIVE_PID=$!

# 5. Setup greeter-sync group and /var/lib state dir
echo "Setting up greeter permissions and state directory..."
if ! getent group greeter-sync >/dev/null; then
    sudo groupadd greeter-sync
fi
sudo usermod -aG greeter-sync "$USER"

sudo mkdir -p /var/lib/greetd/quickshell-greeter
sudo chown root:greeter-sync /var/lib/greetd/quickshell-greeter
sudo chmod 2775 /var/lib/greetd/quickshell-greeter

# 6. Copy deploy tree
echo "Deploying greeter QML..."
sudo mkdir -p /etc/greetd/quickshell-greeter
sudo rsync -a "$REPO_DIR/deploy/etc/greetd/quickshell-greeter/" /etc/greetd/quickshell-greeter/
sudo rsync -a "$REPO_DIR/deploy/etc/greetd/hyprland-greet.lua" /etc/greetd/hyprland-greet.lua

echo ""
echo "Please review PAM configuration diff (if it exists):"
if [ -f /etc/pam.d/quickshell ]; then
    diff -u /etc/pam.d/quickshell "$REPO_DIR/deploy/pam.d/quickshell" || true
else
    echo "(New file: /etc/pam.d/quickshell)"
fi
read -rp "Install PAM config? [y/N] " confirm_pam
if [[ "$confirm_pam" =~ ^[Yy]$ ]]; then
    sudo cp "$REPO_DIR/deploy/pam.d/quickshell" /etc/pam.d/quickshell
    echo "Installed /etc/pam.d/quickshell"
fi

echo ""
echo "Please review config.toml diff (if it exists):"
if [ -f "$REPO_DIR/deploy/etc/greetd/config.toml" ]; then
    if [ -f /etc/greetd/config.toml ]; then
        diff -u /etc/greetd/config.toml "$REPO_DIR/deploy/etc/greetd/config.toml" || true
    else
        echo "(New file: /etc/greetd/config.toml)"
    fi
    read -rp "Install greetd config.toml? [y/N] " confirm_toml
    if [[ "$confirm_toml" =~ ^[Yy]$ ]]; then
        sudo cp "$REPO_DIR/deploy/etc/greetd/config.toml" /etc/greetd/config.toml
        echo "Installed /etc/greetd/config.toml"
    fi
fi

# Print recovery keybind
echo ""
echo "=== IMPORTANT ==="
echo "Add this recovery keybind to your Hyprland config (hyprland.conf):"
cat "$REPO_DIR/deploy/hyprland-keybind.conf.snippet"
echo "================="
echo ""

# 7. Run sync script once
echo "Running initial sync..."
# Since the usermod -aG doesn't apply to the current shell session, we use sudo
# to execute the script as the current user but explicitly specifying the new primary group.
# This avoids sg/newgrp which might prompt for passwords or not be available, and ensures
# the script has the correct permissions to write into the setgid /var/lib directory.
sudo -u "$USER" -g greeter-sync bash "$HOME/.config/quickshell/xeon-shell/deploy/sync-greeter-wallpaper.sh"

echo "Installation complete. Please reboot or restart greetd."
