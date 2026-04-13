#!/bin/sh
# DPI-RIP: fetch subscription for a given sub_id
# Usage: dpi-rip-fetch.sh <sub_id>
#
# URL priority: /tmp/dpi-rip-url-<sub_id>  (written by LuCI before exec)
#               → falls back to UCI dpi-rip.<sub_id>.url
# This two-step approach completely eliminates the UCI commit timing issue.

SUB_ID="${1:?Usage: dpi-rip-fetch.sh <sub_id>}"

# Validate sub_id: alphanumeric + underscore only
case "$SUB_ID" in
    *[!a-zA-Z0-9_]*) echo "DPI-RIP: invalid sub_id" >&2; exit 1 ;;
esac

TMP_URL="/tmp/dpi-rip-url-${SUB_ID}"

# URL: temp file first (written by Lua controller), then UCI
if [ -f "$TMP_URL" ]; then
    SUB_URL=$(cat "$TMP_URL")
    rm -f "$TMP_URL"
else
    SUB_URL=$(uci -q get "dpi-rip.${SUB_ID}.url")
fi

[ -z "$SUB_URL" ] && echo "DPI-RIP: no URL configured for subscription '${SUB_ID}'" >&2 && exit 1

SERVERS_FILE="/etc/dpi-rip/sub_${SUB_ID}.json"
INFO_FILE="/etc/dpi-rip/sub_${SUB_ID}_info.json"
HDR_FILE="/tmp/dpi-rip-hdrs-${SUB_ID}.txt"

mkdir -p /etc/dpi-rip
echo "DPI-RIP: fetching ${SUB_URL}"

# Fetch: try wget then uclient-fetch
if wget -q --server-response --user-agent "Happ/" -O "$SERVERS_FILE" "$SUB_URL" 2>"$HDR_FILE"; then
    :
elif uclient-fetch -q -U "Happ/" -O "$SERVERS_FILE" "$SUB_URL" 2>"$HDR_FILE"; then
    :
else
    echo "DPI-RIP: download failed" >&2
    exit 1
fi

[ ! -s "$SERVERS_FILE" ] && echo "DPI-RIP: empty response from server" >&2 && exit 1

# --- Parse response headers ---
RAW_TITLE=$(grep -i "profile-title:" "$HDR_FILE" | head -1 \
    | sed 's/^[[:space:]]*//;s/.*[Pp]rofile-[Tt]itle:[[:space:]]*//' | tr -d '\r\n')
USERINFO=$(grep -i "subscription-userinfo:" "$HDR_FILE" | head -1 \
    | sed 's/^[[:space:]]*//;s/.*[Ss]ubscription-[Uu]serinfo:[[:space:]]*//' | tr -d '\r\n')

# Decode base64 title if prefixed
TITLE="$RAW_TITLE"
case "$RAW_TITLE" in base64:*|BASE64:*)
    TITLE=$(printf '%s' "${RAW_TITLE#*:}" | base64 -d 2>/dev/null || echo "$RAW_TITLE")
    ;;
esac

# Parse subscription-userinfo fields
_field() { echo "$USERINFO" | grep -o "${1}=[0-9]*" | cut -d= -f2; }
UPLOAD=$(_field upload);   UPLOAD=${UPLOAD:-0}
DOWNLOAD=$(_field download); DOWNLOAD=${DOWNLOAD:-0}
TOTAL=$(_field total);     TOTAL=${TOTAL:-0}
EXPIRE=$(_field expire);   EXPIRE=${EXPIRE:-0}

fmt_bytes() {
    awk -v n="$1" 'BEGIN{
        if     (n<1024)       printf "%.0f B\n",   n
        else if(n<1048576)    printf "%.1f KB\n",  n/1024
        else if(n<1073741824) printf "%.2f MB\n",  n/1048576
        else                  printf "%.2f GB\n",  n/1073741824
    }'
}

USED=$(awk -v u="$UPLOAD" -v d="$DOWNLOAD" 'BEGIN{print u+d}')
USED_FMT=$(fmt_bytes "$USED")
TOTAL_FMT=$([ "$TOTAL" -gt 0 ] && fmt_bytes "$TOTAL" || echo "∞")
USED_PCT=0
[ "$TOTAL" -gt 0 ] && USED_PCT=$(awk -v u="$USED" -v t="$TOTAL" 'BEGIN{printf "%.1f",u/t*100}')

EXPIRE_STR=""
[ "$EXPIRE" -gt 0 ] && EXPIRE_STR=$(date -d "@$EXPIRE" "+%Y-%m-%d" 2>/dev/null || echo "$EXPIRE")

# Count servers (entries with "remarks" key)
COUNT=$(jsonfilter -i "$SERVERS_FILE" -e '@[*].remarks' 2>/dev/null | wc -l | tr -d ' ')
[ -z "$COUNT" ] || [ "$COUNT" = "0" ] && \
    COUNT=$(grep -c '"remarks"' "$SERVERS_FILE" 2>/dev/null || echo 0)

# Escape title for JSON
TITLE_ESC=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g;s/"/\\"/g')

cat > "$INFO_FILE" << EOF
{
  "title":      "$TITLE_ESC",
  "upload":     $UPLOAD,
  "download":   $DOWNLOAD,
  "total":      $TOTAL,
  "expire":     $EXPIRE,
  "expire_str": "$EXPIRE_STR",
  "used_fmt":   "$USED_FMT",
  "total_fmt":  "$TOTAL_FMT",
  "used_pct":   $USED_PCT,
  "count":      $COUNT
}
EOF

# Cache the title in UCI so it shows even before next fetch
if [ -n "$TITLE" ]; then
    TITLE_SHORT=$(printf '%s' "$TITLE" | cut -c1-80)
    uci -q set "dpi-rip.${SUB_ID}.title=$TITLE_SHORT" && uci -q commit dpi-rip
fi

rm -f "$HDR_FILE"

echo "DPI-RIP[$SUB_ID]: OK — ${COUNT} servers${TITLE:+ | $TITLE}"
[ -n "$EXPIRE_STR" ] && echo "  expires: $EXPIRE_STR | used: $USED_FMT / $TOTAL_FMT"
