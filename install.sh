#!/bin/sh
# DPI-RIP — install from GitHub
# Usage: wget -O- https://raw.githubusercontent.com/LL33ch/test/main/install.sh | sh

set -e

RAW="https://raw.githubusercontent.com/LL33ch/test/main/luci-app-dpi-rip"

echo "==> DPI-RIP installer"

mkdir -p /etc/dpi-rip
mkdir -p /usr/lib/lua/luci/controller
mkdir -p /usr/lib/lua/luci/view/dpi_rip
mkdir -p /usr/share/rpcd/acl.d

dl() { wget -q -O "$2" "${RAW}/$1" || { echo "  !! failed: $1" >&2; exit 1; }; }

echo "  -> downloading files"

# UCI config: never overwrite — preserves user's subscriptions and settings
[ ! -f /etc/config/dpi-rip ] && dl "files/etc/config/dpi-rip" /etc/config/dpi-rip

dl "files/etc/init.d/dpi-rip"                         /etc/init.d/dpi-rip
dl "root/usr/bin/dpi-rip-fetch.sh"                    /usr/bin/dpi-rip-fetch.sh
dl "root/usr/bin/dpi-rip-gen.sh"                      /usr/bin/dpi-rip-gen.sh
dl "root/usr/bin/dpi-rip-list.sh"                     /usr/bin/dpi-rip-list.sh
dl "root/usr/share/rpcd/acl.d/luci-app-dpi-rip.json" /usr/share/rpcd/acl.d/luci-app-dpi-rip.json
dl "luasrc/controller/dpi_rip.lua"                    /usr/lib/lua/luci/controller/dpi_rip.lua
dl "luasrc/view/dpi_rip/overview.htm"                 /usr/lib/lua/luci/view/dpi_rip/overview.htm
dl "luasrc/view/dpi_rip/subs.htm"                     /usr/lib/lua/luci/view/dpi_rip/subs.htm
dl "luasrc/view/dpi_rip/log.htm"                      /usr/lib/lua/luci/view/dpi_rip/log.htm

echo "  -> setting permissions"
chmod +x /etc/init.d/dpi-rip
chmod +x /usr/bin/dpi-rip-fetch.sh
chmod +x /usr/bin/dpi-rip-gen.sh
chmod +x /usr/bin/dpi-rip-list.sh

echo "  -> enabling service"
/etc/init.d/dpi-rip enable

echo "  -> restarting LuCI"
/etc/init.d/rpcd restart 2>/dev/null || true
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
echo ""
echo "==> Done!"
echo "    Open: http://${LAN_IP}/cgi-bin/luci/admin/services/dpi-rip"
echo ""
echo "    Next steps:"
echo "    1. Go to 'Subscriptions' tab and add your subscription URL"
echo "    2. Select a server on the 'Overview' tab"
echo "    3. Enable and click 'Save & Restart'"
