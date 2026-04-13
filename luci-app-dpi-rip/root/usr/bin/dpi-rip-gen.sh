#!/bin/sh
# DPI-RIP: generate xray config from selected subscription server
# Pure shell — no python3 needed, uses jsonfilter (always present on OpenWRT)

CONFIG_FILE="/etc/dpi-rip/config.json"
TPROXY_PORT=7892

ACTIVE_SUB=$(uci -q get dpi-rip.main.active_sub)
REMARKS=$(uci -q get dpi-rip.main.active_remarks)
PROXY_MODE=$(uci -q get dpi-rip.main.proxy_mode || echo "tproxy")

[ -z "$ACTIVE_SUB" ]  && echo "DPI-RIP: no active subscription set" >&2 && exit 1
[ -z "$REMARKS" ]     && echo "DPI-RIP: no active server set" >&2 && exit 1

SERVERS_FILE="/etc/dpi-rip/sub_${ACTIVE_SUB}.json"
[ ! -f "$SERVERS_FILE" ] && echo "DPI-RIP: servers file missing: $SERVERS_FILE" >&2 && exit 1

# --- Find server index by remarks ---
IDX=0
I=0
while true; do
    R=$(jsonfilter -i "$SERVERS_FILE" -e "@[$I].remarks" 2>/dev/null | sed 's/^"//;s/"$//')
    [ -z "$R" ] && break
    if [ "$R" = "$REMARKS" ]; then
        IDX=$I
        break
    fi
    I=$((I+1))
    [ $I -gt 500 ] && break
done

# --- Extract DNS, outbounds, routing from chosen server ---
DNS=$(      jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].dns")
OUTBOUNDS=$(jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].outbounds")
ROUTING=$(  jsonfilter -i "$SERVERS_FILE" -e "@[$IDX].routing")

if [ -z "$OUTBOUNDS" ]; then
    echo "DPI-RIP: failed to extract outbounds for '$REMARKS' (index $IDX)" >&2
    exit 1
fi

# --- Inject tproxy routing rule ---
if [ "$PROXY_MODE" = "tproxy" ]; then
    ROUTING=$(echo "$ROUTING" | sed \
        's/"rules":\[/"rules":[{"type":"field","inboundTag":["tproxy-in"],"outboundTag":"proxy"},/')
fi

# --- Build inbounds suitable for a router ---
if [ "$PROXY_MODE" = "tproxy" ]; then
    INBOUNDS=$(cat << 'INEOF'
[
        {
            "tag": "tproxy-in",
            "port": 7892,
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
INEOF
)
else
    INBOUNDS=$(cat << 'INEOF'
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
INEOF
)
fi

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

echo "DPI-RIP: config written → $CONFIG_FILE  (sub=$ACTIVE_SUB server='$REMARKS' mode=$PROXY_MODE)"
