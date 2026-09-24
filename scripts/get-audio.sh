#!/usr/bin/env bash
sinks=$(pactl -f json list sinks)
default=$(pactl get-default-sink)
jq -n --argjson sinks "$sinks" --arg def "$default" '{sinks: $sinks, default: $def}'
