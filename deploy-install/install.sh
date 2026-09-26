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
# Using rsync to cleanly exclude deploy/, scratch/, evidence/, deploy-install/ and .git/
rsync -a --exclude 'deploy' --exclude 'scratch' --exclude 'evidence' --exclude 'deploy-install' --exclude '.git' --exclude '.gitignore' "$REPO_DIR/" "$HOME/.config/quickshell/xeon-shell/"

# 3. Settings migration
OLD_CONF="$HOME/.config/Unknown Organization/quickshell.conf"
NEW_CONF_DIR="$HOME/.config/Xeon Shell"
NEW_CONF="$NEW_CONF_DIR/xeon-shell.conf"

if [ -f "$OLD_CONF" ]; then
    echo "Migrating old settings..."
    echo "NOTE: This settings migration runs only via install.sh. Existing users must rerun this script after pulling the rebrand."
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

echo "Setting up greeter permissions and state directory..."
if ! getent group greeter-sync >/dev/null; then
    sudo groupadd greeter-sync
fi
sudo usermod -aG greeter-sync "$USER"

if ! id greeter >/dev/null 2>&1; then
    sudo useradd --system --no-create-home --shell /usr/bin/nologin greeter
fi
sudo usermod -aG greeter-sync greeter
sudo usermod -aG video greeter
sudo usermod -aG input greeter

sudo mkdir -p /var/lib/greetd/quickshell-greeter
sudo chown root:greeter-sync /var/lib/greetd/quickshell-greeter
sudo chmod 2775 /var/lib/greetd/quickshell-greeter

# Pre-flight check for new group
if ! groups | grep -q '\bgreeter-sync\b'; then
    echo "NOTE: 'greeter-sync' group is not active in this shell yet, using sudo -g for sync script."
fi

echo "Deploying greeter files..."
sudo mkdir -p /etc/greetd/quickshell-greeter
sudo rsync -a --exclude '__pycache__' "$REPO_DIR/deploy/etc/greetd/quickshell-greeter/" /etc/greetd/quickshell-greeter/
sudo rsync -a "$REPO_DIR/deploy/etc/greetd/hyprland-greet.lua" /etc/greetd/hyprland-greet.lua
if [ -f /etc/greetd/config.toml ]; then
    sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
    echo "Backed up existing config.toml to config.toml.bak"
fi
sudo cp "$REPO_DIR/deploy/etc/greetd/config.toml" /etc/greetd/config.toml

echo ""
echo "Please review PAM configuration diff (if it exists):"
if [ -f /etc/pam.d/quickshell ]; then
    diff -u /etc/pam.d/quickshell "$REPO_DIR/deploy/pam.d/quickshell" || true
else
    echo "(New file: /etc/pam.d/quickshell)"
fi
read -rp "Install PAM config? [y/N] " confirm_pam
if [[ "$confirm_pam" =~ ^[Yy]$ ]]; then
    [ -f "$REPO_DIR/deploy/pam.d/quickshell" ] || { echo "missing pam source"; exit 1; }
    sudo cp "$REPO_DIR/deploy/pam.d/quickshell" /etc/pam.d/quickshell
    echo "Installed /etc/pam.d/quickshell"
fi

# Print recovery keybind
echo ""
echo "=== IMPORTANT ==="
echo "Add this recovery keybind to your Hyprland config (hyprland.conf):"
cat "$REPO_DIR/deploy/hyprland-keybind.conf.snippet"
echo "================="
echo ""

echo "Running initial sync..."
sudo -u "$USER" -g greeter-sync bash "$REPO_DIR/scripts/sync-greeter-wallpaper.sh"

echo "Writing default greeter config..."
sudo -u "$USER" -g greeter-sync bash -c 'printf "{\n  \"lockscreenAlignment\": \"left\",\n  \"rememberLastUser\": false\n}\n" > /var/lib/greetd/quickshell-greeter/config-snapshot.json && chmod 644 /var/lib/greetd/quickshell-greeter/config-snapshot.json'

echo "Installation complete. Please reboot or restart greetd."
