#!/usr/bin/env bash
# screenshot-config.sh — read/write screenshot & recording config
#
# Usage:
#   screenshot-config.sh read          → prints the JSON config to stdout
#   screenshot-config.sh write KEY VAL → updates a single key in the config
#   screenshot-config.sh init          → ensures config + directories exist

CONFIG_DIR="$HOME/.cache/quickshell-screenshot"
CONFIG_FILE="$CONFIG_DIR/config.json"
FRAMES_DIR="$CONFIG_DIR/frames"

DEFAULT_SS_DIR="$HOME/Pictures/Screenshots"
DEFAULT_REC_DIR="$HOME/Videos/Recordings"

ensure_config() {
    mkdir -p "$CONFIG_DIR" "$FRAMES_DIR"
    if [ ! -s "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
{
    "screenshotDir": "$DEFAULT_SS_DIR",
    "recordingDir": "$DEFAULT_REC_DIR",
    "recordingFps": 24
}
EOF
    fi
    # Ensure save directories exist
    local ssDir recDir
    ssDir=$(jq -r '.screenshotDir // "'"$DEFAULT_SS_DIR"'"' "$CONFIG_FILE")
    recDir=$(jq -r '.recordingDir // "'"$DEFAULT_REC_DIR"'"' "$CONFIG_FILE")
    mkdir -p "$ssDir" "$recDir"
}

case "$1" in
    init)
        ensure_config
        ;;
    read)
        ensure_config
        cat "$CONFIG_FILE"
        ;;
    write)
        ensure_config
        KEY="$2"
        VAL="$3"
        # Update the key in the JSON config
        jq --arg k "$KEY" --arg v "$VAL" '.[$k] = $v' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
            && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        # If changing a directory, ensure it exists
        if [ "$KEY" = "screenshotDir" ] || [ "$KEY" = "recordingDir" ]; then
            mkdir -p "$VAL"
        fi
        ;;
    clean-frames)
        rm -rf "$FRAMES_DIR"/*
        ;;
    encode)
        # encode FPS INPUT_DIR OUTPUT_FILE
        ensure_config
        FPS="$2"
        INPUT_DIR="$3"
        OUTPUT_FILE="$4"
        # Get the directory for the output file and ensure it exists
        mkdir -p "$(dirname "$OUTPUT_FILE")"
        ffmpeg -y -framerate "$FPS" -i "$INPUT_DIR/frame_%05d.jpg" \
            -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
            -c:v libx264 -preset fast -pix_fmt yuv420p \
            -movflags +faststart \
            "$OUTPUT_FILE" 2>/dev/null
        # Cleanup frames
        rm -rf "$INPUT_DIR"/*
        ;;
    *)
        echo "Usage: $0 {init|read|write|clean-frames|encode}" >&2
        exit 1
        ;;
esac
