#!/bin/sh
# DPI-RIP — установка с GitHub
# wget -O- https://raw.githubusercontent.com/LL33ch/test/main/install.sh | sh

set -e

RAW="https://raw.githubusercontent.com/LL33ch/test/main/luci-app-dpi-rip"

echo "==> DPI-RIP installer"

mkdir -p /etc/dpi-rip
mkdir -p /usr/lib/lua/luci/controller
mkdir -p /usr/lib/lua/luci/view/dpi_rip
mkdir -p /usr/share/rpcd/acl.d

dl() { wget -q -O "$2" "${RAW}/$1"; }

echo "  -> files"
# Конфиг не перезаписываем — сохраняем настройки пользователя
[ ! -f /etc/config/dpi-rip ] && dl "files/etc/config/dpi-rip" /etc/config/dpi-rip
dl "files/etc/init.d/dpi-rip"                          /etc/init.d/dpi-rip
dl "root/usr/bin/dpi-rip-fetch.sh"                     /usr/bin/dpi-rip-fetch.sh
dl "root/usr/bin/dpi-rip-gen.sh"                       /usr/bin/dpi-rip-gen.sh
dl "root/usr/share/rpcd/acl.d/luci-app-dpi-rip.json"  /usr/share/rpcd/acl.d/luci-app-dpi-rip.json
dl "luasrc/controller/dpi_rip.lua"                     /usr/lib/lua/luci/controller/dpi_rip.lua
dl "luasrc/view/dpi_rip/overview.htm"                  /usr/lib/lua/luci/view/dpi_rip/overview.htm
dl "luasrc/view/dpi_rip/log.htm"                       /usr/lib/lua/luci/view/dpi_rip/log.htm

echo "  -> permissions"
chmod +x /etc/init.d/dpi-rip
chmod +x /usr/bin/dpi-rip-fetch.sh
chmod +x /usr/bin/dpi-rip-gen.sh

/etc/init.d/dpi-rip enable

echo "  -> restart services"
/etc/init.d/rpcd restart 2>/dev/null
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null
/etc/init.d/uhttpd restart 2>/dev/null

echo ""
echo "==> Done: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1')/cgi-bin/luci/admin/services/dpi-rip"
