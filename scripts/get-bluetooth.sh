#!/usr/bin/env bash
info=$(bluetoothctl info)
connected=$(echo "$info" | grep "Connected: yes")
if [ -z "$connected" ]; then
    echo '{"connected": false}'
else
    name=$(echo "$info" | awk -F': ' '/Alias:/ {print $2}')
    battery=$(echo "$info" | grep -o 'Battery Percentage:.*' | grep -oE '\([0-9]+\)' | tr -d '()')
    icon=$(echo "$info" | grep "Icon:" | sed 's/^\s*Icon: //')
    jq -c -n --arg n "$name" --arg b "$battery" --arg i "$icon" '{connected: true, name: $n, battery: $b, icon: $i}'
fi
