#!/bin/bash
# sync-greeter-wallpaper.sh
# Copies the current wallpaper and config snapshot to the greeter's state directory.
# Runs as the normal user without sudo.

STATE_DIR="${GREETER_STATE_DIR:-/var/lib/greetd/quickshell-greeter}"
WALLPAPER="$HOME/.wa.jpg"
CONF_FILE="$HOME/.config/Xeon Shell/xeon-shell.conf"

if [ ! -d "$STATE_DIR" ] || [ ! -w "$STATE_DIR" ]; then
    echo "ERROR: Target directory $STATE_DIR does not exist or is not writable." >&2
    echo "Have you completed the one-time privileged setup (groupadd, usermod, chown, chmod 2775) and re-logged in?" >&2
    exit 1
fi

if [ -f "$WALLPAPER" ]; then
    cp "$WALLPAPER" "$STATE_DIR/wallpaper.jpg"
    chmod 644 "$STATE_DIR/wallpaper.jpg"
    echo "Greeter wallpaper updated."
else
    echo "Wallpaper file $WALLPAPER not found!"
fi

ALIGN="left"
REMEMBER="false"
if [ -f "$CONF_FILE" ]; then
    ALIGN=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONF_FILE'); print(c.get('General', 'lockscreenAlignment', fallback='left'))")
    REMEMBER=$(python3 -c "import configparser; c=configparser.ConfigParser(); c.read('$CONF_FILE'); val=c.get('General', 'rememberLastUser', fallback='false'); print('true' if val.lower()=='true' else 'false')")
fi

printf '{\n  "lockscreenAlignment": "%s",\n  "rememberLastUser": %s\n}\n' "$ALIGN" "$REMEMBER" > "$STATE_DIR/config-snapshot.json"
chmod 644 "$STATE_DIR/config-snapshot.json"
echo "Greeter config snapshot updated."
