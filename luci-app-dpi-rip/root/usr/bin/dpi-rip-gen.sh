#!/bin/sh
# DPI-RIP: генератор xray конфига — чистый shell, python3 не нужен
# Использует jsonfilter (libubox, всегда есть на OpenWRT)

CONFIG_FILE="/etc/dpi-rip/config.json"
SERVERS_FILE="/etc/dpi-rip/servers.json"
TPROXY_PORT=7892

[ ! -f "$SERVERS_FILE" ] && echo "DPI-RIP: no servers.json, run fetch first" >&2 && exit 1

REMARKS=$(uci -q get dpi-rip.main.active_remarks)
PROXY_MODE=$(uci -q get dpi-rip.main.proxy_mode || echo "tproxy")

# --- Найти индекс сервера по remarks ---
IDX=0
I=0
while true; do
    R=$(jsonfilter -i "$SERVERS_FILE" -e "@[$I].remarks" 2>/dev/null)
    [ -z "$R" ] && break
    R=$(echo "$R" | tr -d '"')           # убираем кавычки из JSON-строки
    [ "$R" = "$REMARKS" ] && IDX=$I && break
    I=$((I+1))
    [ $I -gt 200 ] && break              # защита от бесконечного цикла
done

# --- Извлекаем нужные секции из выбранного сервера ---
DNS=$(      jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].dns")
OUTBOUNDS=$(jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].outbounds")
ROUTING=$(  jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].routing")

if [ -z "$OUTBOUNDS" ]; then
    echo "DPI-RIP: failed to extract outbounds for server $IDX" >&2
    exit 1
fi

# --- Добавляем правило маршрутизации для tproxy ---
if [ "$PROXY_MODE" = "tproxy" ]; then
    ROUTING=$(echo "$ROUTING" | sed \
        's/"rules":\[/"rules":[{"type":"field","inboundTag":["tproxy-in"],"outboundTag":"proxy"},/')
fi

# --- Строим inbounds под роутер (вместо localhost-only из подписки) ---
if [ "$PROXY_MODE" = "tproxy" ]; then
    INBOUNDS=$(cat << EOF
[
        {
            "tag": "tproxy-in",
            "port": $TPROXY_PORT,
            "protocol": "dokodemo-door",
            "settings": { "network": "tcp,udp", "followRedirect": true },
            "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] },
            "streamSettings": { "sockopt": { "tproxy": "tproxy" } }
        },
        {
            "tag": "socks",
            "port": 10808,
            "listen": "0.0.0.0",
            "protocol": "socks",
            "settings": { "udp": true },
            "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
        },
        {
            "tag": "http",
            "port": 10809,
            "listen": "0.0.0.0",
            "protocol": "http",
            "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
        }
    ]
EOF
)
else
    INBOUNDS=$(cat << EOF
[
        {
            "tag": "socks",
            "port": 10808,
            "listen": "0.0.0.0",
            "protocol": "socks",
            "settings": { "udp": true },
            "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
        },
        {
            "tag": "http",
            "port": 10809,
            "listen": "0.0.0.0",
            "protocol": "http",
            "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
        }
    ]
EOF
)
fi

# --- Собираем финальный конфиг ---
mkdir -p "$(dirname "$CONFIG_FILE")"

cat > "$CONFIG_FILE" << EOF
{
    "log": {
        "loglevel": "warning",
        "error":    "/var/log/dpi-rip-error.log",
        "access":   "/var/log/dpi-rip-access.log"
    },
    "dns":       $DNS,
    "inbounds":  $INBOUNDS,
    "outbounds": $OUTBOUNDS,
    "routing":   $ROUTING
}
EOF

echo "DPI-RIP: config written to $CONFIG_FILE"
