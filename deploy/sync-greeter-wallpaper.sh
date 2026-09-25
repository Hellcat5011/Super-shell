#!/bin/bash
# sync-greeter-wallpaper.sh
# Copies the current wallpaper to the greeter's asset directory.
# Must run as root (or via sudo) to write to /etc/greetd/

GREETER_ASSET_DIR="/etc/greetd/quickshell-greeter/assets"
WALLPAPER="$HOME/.wa.jpg"

if [ -f "$WALLPAPER" ]; then
    mkdir -p "$GREETER_ASSET_DIR"
    cp "$WALLPAPER" "$GREETER_ASSET_DIR/wallpaper.jpg"
    chmod 644 "$GREETER_ASSET_DIR/wallpaper.jpg"
    chown root:root "$GREETER_ASSET_DIR/wallpaper.jpg"
    echo "Greeter wallpaper updated."
else
    echo "Wallpaper file $WALLPAPER not found!"
    exit 1
fi
