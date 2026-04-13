#!/bin/sh
# DPI-RIP — установка прямо с GitHub
# Запуск на роутере:
#   wget -O- https://raw.githubusercontent.com/LL33ch/test/main/install.sh | sh

set -e

REPO="https://github.com/LL33ch/test"
RAW="https://raw.githubusercontent.com/LL33ch/test/main"
TMP="/tmp/dpi-rip-install"
PKG="luci-app-dpi-rip"

echo "==> DPI-RIP installer"

# --- Создаём директории ---
mkdir -p "$TMP"
mkdir -p /etc/dpi-rip
mkdir -p /usr/lib/lua/luci/controller
mkdir -p /usr/lib/lua/luci/model/cbi/dpi_rip
mkdir -p /usr/lib/lua/luci/view/dpi_rip
mkdir -p /usr/share/rpcd/acl.d

# --- Скачиваем файлы ---
echo "  -> downloading files"

dl() {
    wget -q -O "$2" "${RAW}/${PKG}/$1"
}

dl "files/etc/config/dpi-rip"                              /etc/config/dpi-rip
dl "files/etc/init.d/dpi-rip"                             /etc/init.d/dpi-rip
dl "root/usr/bin/dpi-rip-gen.sh"                          /usr/bin/dpi-rip-gen.sh
dl "root/usr/share/rpcd/acl.d/luci-app-dpi-rip.json"     /usr/share/rpcd/acl.d/luci-app-dpi-rip.json
dl "luasrc/controller/dpi_rip.lua"                         /usr/lib/lua/luci/controller/dpi_rip.lua
dl "luasrc/model/cbi/dpi_rip/overview.lua"                /usr/lib/lua/luci/model/cbi/dpi_rip/overview.lua
dl "luasrc/model/cbi/dpi_rip/servers.lua"                 /usr/lib/lua/luci/model/cbi/dpi_rip/servers.lua
dl "luasrc/view/dpi_rip/overview.htm"                     /usr/lib/lua/luci/view/dpi_rip/overview.htm
dl "luasrc/view/dpi_rip/log.htm"                          /usr/lib/lua/luci/view/dpi_rip/log.htm

# --- Права ---
echo "  -> setting permissions"
chmod +x /etc/init.d/dpi-rip
chmod +x /usr/bin/dpi-rip-gen.sh

# --- Включаем сервис ---
/etc/init.d/dpi-rip enable

# --- Применяем ACL и сбрасываем кэш ---
/etc/init.d/rpcd restart 2>/dev/null
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null
/etc/init.d/uhttpd restart 2>/dev/null

rm -rf "$TMP"

echo ""
echo "==> Done!"
echo "    Open LuCI: http://$(uci get network.lan.ipaddr)/cgi-bin/luci/admin/services/dpi-rip"
