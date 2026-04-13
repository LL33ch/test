#!/bin/sh
# DPI-RIP: list servers from a subscription JSON file
# Usage: dpi-rip-list.sh <json_file>
# Output: tab-separated lines: remarks<TAB>protocol

FILE="$1"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 1

I=0
while true; do
    R=$(jsonfilter -i "$FILE" -e "@[$I].remarks" 2>/dev/null)
    [ -z "$R" ] && break
    # Strip surrounding JSON quotes
    R=$(echo "$R" | sed 's/^"//;s/"$//')
    P=$(jsonfilter -i "$FILE" -e "@[$I].outbounds[0].protocol" 2>/dev/null | sed 's/^"//;s/"$//')
    [ -z "$P" ] && P="unknown"
    printf '%s\t%s\n' "$R" "$P"
    I=$((I+1))
    [ $I -gt 500 ] && break
done
