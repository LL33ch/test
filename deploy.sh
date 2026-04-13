#!/bin/bash
# DPI-RIP — deploy via SSH (for development/testing)
# Usage: bash deploy.sh [router_ip]
#   router_ip defaults to 192.168.1.1

set -e

ROUTER_IP="${1:-192.168.1.1}"
ROUTER="root@${ROUTER_IP}"
PKG="luci-app-dpi-rip"

echo "==> DPI-RIP deploy → $ROUTER_IP"

# Create required directories
ssh "$ROUTER" "
    mkdir -p /etc/dpi-rip
    mkdir -p /usr/lib/lua/luci/controller
    mkdir -p /usr/lib/lua/luci/view/dpi_rip
    mkdir -p /usr/share/rpcd/acl.d
"

echo "  -> copying files"
scp "$PKG/files/etc/init.d/dpi-rip"                         "$ROUTER:/etc/init.d/dpi-rip"
scp "$PKG/root/usr/bin/dpi-rip-fetch.sh"                    "$ROUTER:/usr/bin/dpi-rip-fetch.sh"
scp "$PKG/root/usr/bin/dpi-rip-gen.sh"                      "$ROUTER:/usr/bin/dpi-rip-gen.sh"
scp "$PKG/root/usr/bin/dpi-rip-list.sh"                     "$ROUTER:/usr/bin/dpi-rip-list.sh"
scp "$PKG/root/usr/share/rpcd/acl.d/luci-app-dpi-rip.json" "$ROUTER:/usr/share/rpcd/acl.d/luci-app-dpi-rip.json"
scp "$PKG/luasrc/controller/dpi_rip.lua"                    "$ROUTER:/usr/lib/lua/luci/controller/dpi_rip.lua"
scp "$PKG/luasrc/view/dpi_rip/overview.htm"                 "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/overview.htm"
scp "$PKG/luasrc/view/dpi_rip/subs.htm"                     "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/subs.htm"
scp "$PKG/luasrc/view/dpi_rip/log.htm"                      "$ROUTER:/usr/lib/lua/luci/view/dpi_rip/log.htm"

# Install default config only if not present
ssh "$ROUTER" "[ -f /etc/config/dpi-rip ]" 2>/dev/null || \
    scp "$PKG/files/etc/config/dpi-rip" "$ROUTER:/etc/config/dpi-rip"

echo "  -> apply permissions & restart LuCI"
ssh "$ROUTER" "
    chmod +x /etc/init.d/dpi-rip \
              /usr/bin/dpi-rip-fetch.sh \
              /usr/bin/dpi-rip-gen.sh \
              /usr/bin/dpi-rip-list.sh
    /etc/init.d/dpi-rip enable
    /etc/init.d/rpcd restart 2>/dev/null || true
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null || true
    /etc/init.d/uhttpd restart 2>/dev/null || true
    echo 'OK'
"

echo ""
echo "==> Done: http://${ROUTER_IP}/cgi-bin/luci/admin/services/dpi-rip"
