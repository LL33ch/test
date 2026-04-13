#!/bin/bash
# DPI-RIP deploy script
# Использование: ./deploy.sh 192.168.1.1
# или:           ROUTER=root@192.168.1.1 ./deploy.sh

set -e

ROUTER_IP="${1:-192.168.1.1}"
ROUTER="root@${ROUTER_IP}"
PKG="luci-app-dpi-rip"

echo "==> Deploying DPI-RIP to $ROUTER_IP"

# --- Создаём директории ---
ssh "$ROUTER" "
    mkdir -p /etc/dpi-rip
    mkdir -p /usr/lib/lua/luci/controller
    mkdir -p /usr/lib/lua/luci/model/cbi/dpi_rip
    mkdir -p /usr/lib/lua/luci/view/dpi_rip
"

# --- Копируем файлы ---
echo "  -> config"
scp "$PKG/files/etc/config/dpi-rip"            "$ROUTER:/etc/config/dpi-rip"

echo "  -> init.d"
scp "$PKG/files/etc/init.d/dpi-rip"            "$ROUTER:/etc/init.d/dpi-rip"
ssh "$ROUTER" "chmod +x /etc/init.d/dpi-rip"

echo "  -> generator"
scp "$PKG/root/usr/bin/dpi-rip-gen.sh"         "$ROUTER:/usr/bin/dpi-rip-gen.sh"
ssh "$ROUTER" "chmod +x /usr/bin/dpi-rip-gen.sh"

echo "  -> luci controller"
scp "$PKG/luasrc/controller/dpi_rip.lua"        "$ROUTER:/usr/lib/lua/luci/controller/"

echo "  -> luci models"
scp "$PKG/luasrc/model/cbi/dpi_rip/overview.lua" "$ROUTER:/usr/lib/lua/luci/model/cbi/dpi_rip/"
scp "$PKG/luasrc/model/cbi/dpi_rip/servers.lua"  "$ROUTER:/usr/lib/lua/luci/model/cbi/dpi_rip/"

echo "  -> luci views"
scp "$PKG/luasrc/view/dpi_rip/overview.htm"    "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/"
scp "$PKG/luasrc/view/dpi_rip/log.htm"         "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/"

# --- Сбрасываем кэш LuCI ---
echo "  -> clearing LuCI cache"
ssh "$ROUTER" "rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null; true"

echo ""
echo "==> Done! Open: http://${ROUTER_IP}/cgi-bin/luci/admin/services/dpi-rip"
echo ""
echo "    Quick test on router:"
echo "    ssh root@${ROUTER_IP} '/usr/bin/dpi-rip-gen.sh && xray -test -c /etc/dpi-rip/config.json'"
