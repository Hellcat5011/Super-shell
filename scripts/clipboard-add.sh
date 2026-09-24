#!/usr/bin/env bash
TYPE=$1
CACHE_DIR="$HOME/.cache/quickshell-clipboard"
IMAGE_DIR="$CACHE_DIR/images"
HISTORY_FILE="$CACHE_DIR/history.json"
MAX_ITEMS=50
ID=$(date +%s%N)

# Ensure directories exist
mkdir -p "$IMAGE_DIR"

# Initialize JSON if not exists
if [ ! -s "$HISTORY_FILE" ]; then
    echo "[]" > "$HISTORY_FILE"
fi

if [ "$TYPE" = "text" ]; then
    CONTENT=$(cat)
    
    # Ignore empty strings
    if [ -z "$CONTENT" ]; then
        exit 0
    fi

    # Deduplication logic
    # Get the most recent text item's content
    LAST_CONTENT=$(jq -r 'map(select(.isImage == false)) | .[0].content // empty' "$HISTORY_FILE")
    
    # If the new content is exactly the same as the last content, don't add it
    if [ "$CONTENT" == "$LAST_CONTENT" ]; then
        exit 0
    fi
    
    JSON_ITEM=$(jq -n --arg id "$ID" --arg content "$CONTENT" '{id: $id, isImage: false, content: $content}')
    
elif [ "$TYPE" = "image" ]; then
    IMAGE_PATH="$IMAGE_DIR/clip-$ID.png"
    cat > "$IMAGE_PATH"
    
    # Check if the image is valid
    if [ ! -s "$IMAGE_PATH" ]; then
        rm -f "$IMAGE_PATH"
        exit 0
    fi
    
    JSON_ITEM=$(jq -n --arg id "$ID" --arg path "file://$IMAGE_PATH" '{id: $id, isImage: true, content: "", imagePath: $path}')
else
    exit 1
fi

# Prepend and limit to MAX_ITEMS
jq --argjson item "$JSON_ITEM" --arg max "$MAX_ITEMS" '([$item] + .) | .[0:($max|tonumber)]' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
