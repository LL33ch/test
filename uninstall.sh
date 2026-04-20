#!/bin/sh
#
# Удаление dpi-rip-node с OpenWRT
#
#   curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/uninstall.sh | sh

set -eu

step() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[0;32m✓\033[0m %s\n" "$*"; }

# ── Сервис ────────────────────────────────────────────────────────────────────

step "Stopping service"

/etc/init.d/dpi-rip-node stop    2>/dev/null || true
/etc/init.d/dpi-rip-node disable 2>/dev/null || true
ok "Service stopped"

# ── Файлы ─────────────────────────────────────────────────────────────────────

step "Removing files"

rm -f /usr/sbin/dpi-rip-node
rm -f /etc/init.d/dpi-rip-node
rm -f /etc/hotplug.d/iface/30-dpi-rip-node
ok "Package files removed"

rm -f /www/luci-static/resources/view/dpi-rip-node/settings.js
rm -f /usr/share/luci/menu.d/luci-app-dpi-rip-node.json
rm -f /usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json
rm -f /usr/libexec/rpcd/dpi-rip-node
ok "LuCI files removed"

# ── Конфиг ────────────────────────────────────────────────────────────────────

step "Removing config"

rm -f /etc/config/dpi-rip-node
ok "UCI config removed"

# ── Кэш LuCI ─────────────────────────────────────────────────────────────────

/etc/init.d/rpcd restart 2>/dev/null || true
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-* 2>/dev/null || true
ok "LuCI cache cleared"

# ── Готово ────────────────────────────────────────────────────────────────────

printf "\n\033[1;32mUninstallation complete!\033[0m\n\n"
