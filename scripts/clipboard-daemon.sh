#!/usr/bin/env bash

# Kill existing QuickShell clipboard watchers to avoid duplicates
pkill -f "wl-paste -t text/plain --watch .*clipboard-add.sh text"
pkill -f "wl-paste -t image/png --watch .*clipboard-add.sh image"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wl-paste -t text/plain --watch "$SCRIPT_DIR/clipboard-add.sh" text &
wl-paste -t image/png --watch "$SCRIPT_DIR/clipboard-add.sh" image &

wait
