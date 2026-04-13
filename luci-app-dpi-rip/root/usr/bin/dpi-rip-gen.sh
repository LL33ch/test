#!/bin/sh
# DPI-RIP: генератор конфига xray из UCI
# Читает /etc/config/dpi-rip → записывает /etc/dpi-rip/config.json

CONFIG_FILE="/etc/dpi-rip/config.json"
UCI_CONFIG="dpi-rip"

TPROXY_PORT=7892
SOCKS_PORT=7891
API_PORT=7893

base64_decode() {
    echo "$1" | tr -- '-_' '+/' | base64 -d 2>/dev/null
}

# --- Парсеры протоколов ---

parse_vless() {
    local url="$1"
    local body="${url#vless://}"

    local userinfo="${body%%@*}"
    local rest="${body#*@}"
    local hostport="${rest%%\?*}"
    local params="${rest#*\?}"; params="${params%%#*}"

    local host="${hostport%%:*}"
    local port="${hostport##*:}"
    local uuid="$userinfo"

    local security type path sni pbk sid fp
    security=$(echo "$params" | tr '&' '\n' | grep '^security=' | cut -d= -f2)
    type=$(echo "$params"     | tr '&' '\n' | grep '^type='     | cut -d= -f2)
    path=$(echo "$params"     | tr '&' '\n' | grep '^path='     | cut -d= -f2 \
           | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "/")
    sni=$(echo "$params"      | tr '&' '\n' | grep '^sni='      | cut -d= -f2)
    pbk=$(echo "$params"      | tr '&' '\n' | grep '^pbk='      | cut -d= -f2)
    sid=$(echo "$params"      | tr '&' '\n' | grep '^sid='      | cut -d= -f2)
    fp=$(echo "$params"       | tr '&' '\n' | grep '^fp='       | cut -d= -f2)

    [ -z "$sni" ]      && sni="$host"
    [ -z "$security" ] && security="none"
    [ -z "$type" ]     && type="tcp"

    build_vless_json "$uuid" "$host" "$port" "$security" "$type" "$path" "$sni" "$pbk" "$sid" "$fp"
}

build_vless_json() {
    local uuid="$1" host="$2" port="$3" security="$4"
    local network="$5" path="$6" sni="$7" pbk="$8" sid="$9" fp="${10}"

    local network_block
    case "$network" in
        ws)   network_block="\"wsSettings\": { \"path\": \"${path}\", \"headers\": { \"Host\": \"${sni}\" } }" ;;
        grpc) network_block="\"grpcSettings\": { \"serviceName\": \"${path}\" }" ;;
        *)    network_block="" ;;
    esac

    local tls_block
    case "$security" in
        tls)     tls_block="\"tlsSettings\": { \"serverName\": \"${sni}\", \"fingerprint\": \"${fp:-chrome}\" }" ;;
        reality) tls_block="\"realitySettings\": { \"serverName\": \"${sni}\", \"fingerprint\": \"${fp:-chrome}\", \"publicKey\": \"${pbk}\", \"shortId\": \"${sid}\" }" ;;
        *)       tls_block="" ;;
    esac

    local stream="{
        \"network\": \"${network}\",
        \"security\": \"${security}\""
    [ -n "$network_block" ] && stream="${stream},
        ${network_block}"
    [ -n "$tls_block" ]     && stream="${stream},
        ${tls_block}"
    stream="${stream}
    }"

    cat <<EOF
{
    "tag": "proxy",
    "protocol": "vless",
    "settings": {
        "vnext": [{
            "address": "${host}",
            "port": ${port},
            "users": [{
                "id": "${uuid}",
                "encryption": "none",
                "flow": ""
            }]
        }]
    },
    "streamSettings": ${stream}
}
EOF
}

parse_vmess() {
    local url="$1"
    local b64="${url#vmess://}"
    local json
    json=$(base64_decode "$b64") || { echo "DPI-RIP: invalid vmess URL" >&2; return 1; }

    local host port uuid aid net path tls sni
    host=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('add',''))")
    port=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('port',''))")
    uuid=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
    aid=$(echo  "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('aid','0'))")
    net=$(echo  "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('net','tcp'))")
    path=$(echo "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path','/'))")
    tls=$(echo  "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tls',''))")
    sni=$(echo  "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sni','') or d.get('host',''))")
    [ -z "$sni" ] && sni="$host"

    local network_block tls_block
    [ "$net" = "ws" ]  && network_block="\"wsSettings\": { \"path\": \"${path}\", \"headers\": { \"Host\": \"${sni}\" } }"
    [ "$tls" = "tls" ] && tls_block="\"tlsSettings\": { \"serverName\": \"${sni}\" }"

    local stream="{\"network\": \"${net}\", \"security\": \"${tls:-none}\""
    [ -n "$network_block" ] && stream="${stream}, ${network_block}"
    [ -n "$tls_block" ]     && stream="${stream}, ${tls_block}"
    stream="${stream}}"

    cat <<EOF
{
    "tag": "proxy",
    "protocol": "vmess",
    "settings": {
        "vnext": [{
            "address": "${host}",
            "port": ${port},
            "users": [{ "id": "${uuid}", "alterId": ${aid} }]
        }]
    },
    "streamSettings": ${stream}
}
EOF
}

parse_trojan() {
    local url="$1"
    local body="${url#trojan://}"
    local password="${body%%@*}"
    local rest="${body#*@}"
    local hostport="${rest%%\?*}"
    local params="${rest#*\?}"; params="${params%%#*}"

    local host="${hostport%%:*}"
    local port="${hostport##*:}"
    local sni
    sni=$(echo "$params" | tr '&' '\n' | grep '^sni=' | cut -d= -f2)
    [ -z "$sni" ] && sni="$host"

    cat <<EOF
{
    "tag": "proxy",
    "protocol": "trojan",
    "settings": {
        "servers": [{
            "address": "${host}",
            "port": ${port},
            "password": "${password}"
        }]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": { "serverName": "${sni}" }
    }
}
EOF
}

parse_ss() {
    local url="$1"
    local body="${url#ss://}"; body="${body%%#*}"
    local userinfo rest host port method password

    if echo "$body" | grep -q '@'; then
        userinfo="${body%%@*}"
        rest="${body#*@}"
        host="${rest%%:*}"
        port="${rest##*:}"
        if echo "$userinfo" | grep -q ':'; then
            method="${userinfo%%:*}"; password="${userinfo#*:}"
        else
            local decoded; decoded=$(base64_decode "$userinfo")
            method="${decoded%%:*}"; password="${decoded#*:}"
        fi
    else
        local decoded; decoded=$(base64_decode "${body%%@*}")
        method="${decoded%%:*}"; password="${decoded#*:}"
        rest="${body#*@}"; host="${rest%%:*}"; port="${rest##*:}"
    fi

    cat <<EOF
{
    "tag": "proxy",
    "protocol": "shadowsocks",
    "settings": {
        "servers": [{
            "address": "${host}",
            "port": ${port},
            "method": "${method}",
            "password": "${password}"
        }]
    }
}
EOF
}

parse_link() {
    local link="$1"
    case "$link" in
        vless://*)             parse_vless  "$link" ;;
        vmess://*)             parse_vmess  "$link" ;;
        trojan://*)            parse_trojan "$link" ;;
        ss://*)                parse_ss     "$link" ;;
        *)
            echo "DPI-RIP: unsupported protocol: $link" >&2
            return 1
            ;;
    esac
}

# --- Генерация итогового конфига ---

generate_config() {
    local bypass_cn dns_mode log_level

    config_load "$UCI_CONFIG"
    config_get bypass_cn  main bypass_cn  "1"
    config_get dns_mode   main dns_mode   "doh"
    config_get log_level  main log_level  "warning"

    local active_server
    config_get active_server main active_server ""
    if [ -z "$active_server" ]; then
        echo "DPI-RIP: no active server configured" >&2
        return 1
    fi

    local link
    config_get link "$active_server" link ""
    if [ -z "$link" ]; then
        echo "DPI-RIP: no link for server '$active_server'" >&2
        return 1
    fi

    local outbound_json
    outbound_json=$(parse_link "$link") || return 1

    local dns_block
    case "$dns_mode" in
        doh)
            dns_block='"servers": [
                { "address": "https://1.1.1.1/dns-query", "domains": ["geosite:geolocation-!cn"], "queryStrategy": "UseIPv4" },
                { "address": "114.114.114.114", "domains": ["geosite:cn"], "queryStrategy": "UseIPv4" }
            ]'
            ;;
        *)
            dns_block='"servers": ["1.1.1.1", "8.8.8.8"]'
            ;;
    esac

    local routing_rules=''
    if [ "$bypass_cn" = "1" ]; then
        routing_rules='{
                "type": "field",
                "outboundTag": "direct",
                "domain": ["geosite:cn", "geosite:private"]
            },
            {
                "type": "field",
                "outboundTag": "direct",
                "ip": ["geoip:cn", "geoip:private"]
            },'
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
{
    "log": {
        "loglevel": "${log_level}",
        "access": "/var/log/dpi-rip-access.log",
        "error":  "/var/log/dpi-rip-error.log"
    },
    "dns": {
        ${dns_block}
    },
    "inbounds": [
        {
            "tag": "tproxy-in",
            "port": ${TPROXY_PORT},
            "protocol": "dokodemo-door",
            "settings": { "network": "tcp,udp", "followRedirect": true },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
            "streamSettings": { "sockopt": { "tproxy": "tproxy" } }
        },
        {
            "tag": "socks-in",
            "port": ${SOCKS_PORT},
            "listen": "0.0.0.0",
            "protocol": "socks",
            "settings": { "udp": true }
        },
        {
            "tag": "http-in",
            "port": 7890,
            "listen": "0.0.0.0",
            "protocol": "http"
        }
    ],
    "outbounds": [
        ${outbound_json},
        { "tag": "direct", "protocol": "freedom", "settings": {} },
        { "tag": "block",  "protocol": "blackhole" }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            ${routing_rules}
            {
                "type": "field",
                "inboundTag": ["tproxy-in", "socks-in", "http-in"],
                "outboundTag": "proxy"
            }
        ]
    }
}
EOF

    echo "DPI-RIP: config written to $CONFIG_FILE"
}

. /lib/functions.sh
generate_config
