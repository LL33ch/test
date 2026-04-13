#!/bin/bash
# DPI-RIP — deploy + restart
# Использование (из папки dpi-rip/):
#   bash deploy.sh 192.168.1.1

set -e

ROUTER_IP="${1:-192.168.1.1}"
ROUTER="root@${ROUTER_IP}"
PKG="luci-app-dpi-rip"

echo "==> DPI-RIP deploy → $ROUTER_IP"

# --- Создаём директории на роутере ---
ssh "$ROUTER" "
    mkdir -p /etc/dpi-rip
    mkdir -p /usr/lib/lua/luci/controller
    mkdir -p /usr/lib/lua/luci/model/cbi/dpi_rip
    mkdir -p /usr/lib/lua/luci/view/dpi_rip
"

# --- Копируем файлы ---
echo "  -> files"
scp "$PKG/files/etc/config/dpi-rip"                 "$ROUTER:/etc/config/dpi-rip"
scp "$PKG/files/etc/init.d/dpi-rip"                 "$ROUTER:/etc/init.d/dpi-rip"
scp "$PKG/root/usr/bin/dpi-rip-gen.sh"              "$ROUTER:/usr/bin/dpi-rip-gen.sh"
scp "$PKG/luasrc/controller/dpi_rip.lua"             "$ROUTER:/usr/lib/lua/luci/controller/"
scp "$PKG/luasrc/model/cbi/dpi_rip/overview.lua"    "$ROUTER:/usr/lib/lua/luci/model/cbi/dpi_rip/"
scp "$PKG/luasrc/model/cbi/dpi_rip/servers.lua"     "$ROUTER:/usr/lib/lua/luci/model/cbi/dpi_rip/"
scp "$PKG/luasrc/view/dpi_rip/overview.htm"         "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/"
scp "$PKG/luasrc/view/dpi_rip/log.htm"              "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/"

# --- Права и перезапуск ---
echo "  -> apply"
ssh "$ROUTER" "
    chmod +x /etc/init.d/dpi-rip /usr/bin/dpi-rip-gen.sh
    /etc/init.d/dpi-rip enable
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null
    echo 'OK'
"

echo ""
echo "==> Done: http://${ROUTER_IP}/cgi-bin/luci/admin/services/dpi-rip"
