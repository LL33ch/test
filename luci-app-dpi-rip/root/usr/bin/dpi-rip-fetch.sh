#!/bin/sh
# DPI-RIP: загрузка подписки — чистый shell, python3 не нужен

SUB_URL=$(uci -q get dpi-rip.main.sub_url)
SERVERS_FILE="/etc/dpi-rip/servers.json"
INFO_FILE="/etc/dpi-rip/sub-info.json"
HDR_FILE="/tmp/dpi-rip-hdrs.txt"

[ -z "$SUB_URL" ] && echo "DPI-RIP: sub_url not set" >&2 && exit 1

mkdir -p /etc/dpi-rip
echo "DPI-RIP: fetching $SUB_URL"

# Fetch тела + заголовков: wget -S пишет заголовки в stderr
if wget -q --server-response --user-agent "Happ/" -O "$SERVERS_FILE" "$SUB_URL" 2>"$HDR_FILE"; then
    :
elif uclient-fetch -q -U "Happ/" -O "$SERVERS_FILE" "$SUB_URL" 2>"$HDR_FILE"; then
    :
else
    echo "DPI-RIP: fetch failed" >&2; exit 1
fi

[ ! -s "$SERVERS_FILE" ] && echo "DPI-RIP: empty response" >&2 && exit 1

# --- Парсинг заголовков ---
RAW_TITLE=$(grep -i "profile-title:" "$HDR_FILE" | head -1 \
    | sed 's/^[[:space:]]*//;s/.*[Pp]rofile-[Tt]itle:[[:space:]]*//' | tr -d '\r\n')
USERINFO=$(grep -i "subscription-userinfo:" "$HDR_FILE" | head -1 \
    | sed 's/^[[:space:]]*//;s/.*[Ss]ubscription-[Uu]serinfo:[[:space:]]*//' | tr -d '\r\n')

# Декодируем base64 заголовок
TITLE="$RAW_TITLE"
case "$RAW_TITLE" in base64:*|BASE64:*)
    TITLE=$(printf '%s' "${RAW_TITLE#*:}" | base64 -d 2>/dev/null || echo "$RAW_TITLE")
    ;;
esac

# Парсим userinfo (upload=N; download=N; total=N; expire=N)
_field() { echo "$USERINFO" | grep -o "${1}=[0-9]*" | cut -d= -f2; }
UPLOAD=$(  _field upload  ); UPLOAD=${UPLOAD:-0}
DOWNLOAD=$(_field download); DOWNLOAD=${DOWNLOAD:-0}
TOTAL=$(   _field total   ); TOTAL=${TOTAL:-0}
EXPIRE=$(  _field expire  ); EXPIRE=${EXPIRE:-0}

# Форматирование байтов через awk
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

# Форматируем дату истечения
EXPIRE_STR=""
[ "$EXPIRE" -gt 0 ] && EXPIRE_STR=$(date -d "@$EXPIRE" "+%Y-%m-%d" 2>/dev/null || echo "$EXPIRE")

COUNT=$(grep -c '"remarks"' "$SERVERS_FILE" 2>/dev/null || echo 0)

# Экранируем title для JSON
TITLE_ESC=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g;s/"/\\"/g')

# Сохраняем мета-информацию
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
  "used_pct":   $USED_PCT
}
EOF

rm -f "$HDR_FILE"
echo "DPI-RIP: OK — $COUNT servers | ${TITLE:-no title}"
[ -n "$EXPIRE_STR" ] && echo "         expires: $EXPIRE_STR | used: $USED_FMT / $TOTAL_FMT"
