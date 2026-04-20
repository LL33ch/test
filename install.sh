#!/bin/sh
#
# dpi-rip-node installer for OpenWRT
#
#   curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh

set -eu

REPO_RAW="https://raw.githubusercontent.com/LL33ch/test/refs/heads/main"
PKG="dpi-rip-node"
LUCI_PKG="luci-app-dpi-rip-node"

# ── Вывод ─────────────────────────────────────────────────────────────────────

step() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[0;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\n\033[0;31m✗ %s\033[0m\n\n" "$*" >&2; exit 1; }

# ── Прогресс-бар ──────────────────────────────────────────────────────────────

BAR_WIDTH=28   # ширина полосы
DL_TOTAL=0     # будет заполнено перед стартом загрузок
DL_CURRENT=0   # сколько файлов уже скачано
DL_BYTES=0     # суммарный размер

draw_bar() {
  local current="$1" total="$2" label="$3"
  local filled empty i pct bar

  filled=$((current * BAR_WIDTH / total))
  empty=$((BAR_WIDTH - filled))
  pct=$((current * 100 / total))

  bar=""
  i=0
  while [ $i -lt $filled ]; do bar="${bar}#"; i=$((i+1)); done
  while [ $i -lt $BAR_WIDTH ]; do bar="${bar}-"; i=$((i+1)); done

  # Форматируем суммарный размер
  local size_str
  if   [ "$DL_BYTES" -ge 1048576 ]; then
    size_str=$(awk "BEGIN{printf \"%.1f MB\",$DL_BYTES/1048576}")
  elif [ "$DL_BYTES" -ge 1024 ]; then
    size_str=$(awk "BEGIN{printf \"%.1f KB\",$DL_BYTES/1024}")
  else
    size_str="${DL_BYTES} B"
  fi

  printf "\r  [%s] %3d%%  %-26s  %s" "$bar" "$pct" "$label" "$size_str"
}

download() {
  local url="$1" dst="$2"
  local name bytes

  name="$(basename "$dst")"
  mkdir -p "$(dirname "$dst")"

  draw_bar "$DL_CURRENT" "$DL_TOTAL" "$name"

  wget -qO "$dst" "$url" 2>/dev/null \
    || { printf "\n"; die "Failed to download: $name"; }

  bytes=$(wc -c < "$dst" 2>/dev/null || echo 0)
  DL_CURRENT=$((DL_CURRENT + 1))
  DL_BYTES=$((DL_BYTES + bytes))

  draw_bar "$DL_CURRENT" "$DL_TOTAL" "$name"
}

# ── Проверка окружения ────────────────────────────────────────────────────────

step "Checking environment"

[ -f /etc/openwrt_release ] || die "This script is for OpenWRT only"
ok "OpenWRT detected"

command -v wget >/dev/null || die "wget not found"
command -v uci  >/dev/null || die "uci not found"
command -v opkg >/dev/null || die "opkg not found"

# ── Зависимости ───────────────────────────────────────────────────────────────

step "Checking dependencies"

MISSING=""
for dep in curl jsonfilter; do
  opkg list-installed 2>/dev/null | grep -q "^${dep} " || MISSING="$MISSING $dep"
done

if [ -n "$MISSING" ]; then
  warn "Installing:$MISSING"
  opkg update -q 2>/dev/null || true
  # shellcheck disable=SC2086
  opkg install $MISSING || die "opkg install failed for:$MISSING"
fi

ok "Dependencies satisfied"

# ── Подготовка: считаем сколько файлов качать ─────────────────────────────────

LUCI_AVAILABLE=false
opkg list-installed 2>/dev/null | grep -q "^luci " && LUCI_AVAILABLE=true

CONFIG_EXISTS=false
[ -f /etc/config/dpi-rip-node ] && CONFIG_EXISTS=true

DL_TOTAL=3   # sbin + init.d + hotplug
[ "$CONFIG_EXISTS"   = "false" ] && DL_TOTAL=$((DL_TOTAL + 1))
[ "$LUCI_AVAILABLE"  = "true"  ] && DL_TOTAL=$((DL_TOTAL + 4))

# ── Загрузка файлов ───────────────────────────────────────────────────────────

step "Downloading  ($DL_TOTAL files)"

mkdir -p /etc/config /etc/init.d /etc/hotplug.d/iface /usr/sbin

download "${REPO_RAW}/${PKG}/files/usr/sbin/dpi-rip-node"               /usr/sbin/dpi-rip-node
download "${REPO_RAW}/${PKG}/files/etc/init.d/dpi-rip-node"             /etc/init.d/dpi-rip-node
download "${REPO_RAW}/${PKG}/files/etc/hotplug.d/iface/30-dpi-rip-node" /etc/hotplug.d/iface/30-dpi-rip-node

if [ "$CONFIG_EXISTS" = "false" ]; then
  download "${REPO_RAW}/${PKG}/files/etc/config/dpi-rip-node" /etc/config/dpi-rip-node
fi

if [ "$LUCI_AVAILABLE" = "true" ]; then
  download "${REPO_RAW}/${LUCI_PKG}/htdocs/luci-static/resources/view/dpi-rip-node/settings.js" \
           /www/luci-static/resources/view/dpi-rip-node/settings.js
  download "${REPO_RAW}/${LUCI_PKG}/root/usr/share/luci/menu.d/luci-app-dpi-rip-node.json" \
           /usr/share/luci/menu.d/luci-app-dpi-rip-node.json
  download "${REPO_RAW}/${LUCI_PKG}/root/usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json" \
           /usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json
  download "${REPO_RAW}/${LUCI_PKG}/root/usr/libexec/rpcd/dpi-rip-node" \
           /usr/libexec/rpcd/dpi-rip-node
fi

printf "\n"

if [ "$CONFIG_EXISTS" = "true" ]; then
  warn "Config already exists — skipped (settings preserved)"
fi

# ── Права ─────────────────────────────────────────────────────────────────────

chmod 755 /usr/sbin/dpi-rip-node
chmod 755 /etc/init.d/dpi-rip-node
chmod 755 /etc/hotplug.d/iface/30-dpi-rip-node
chmod 600 /etc/config/dpi-rip-node

if [ "$LUCI_AVAILABLE" = "true" ]; then
  chmod 755 /usr/libexec/rpcd/dpi-rip-node

  # Удаляем старые Lua/CBI файлы от предыдущих установок
  rm -f /usr/lib/lua/luci/controller/dpi_rip_node.lua
  rm -f /usr/lib/lua/luci/model/cbi/dpi_rip_node.lua

  /etc/init.d/rpcd restart 2>/dev/null || true
  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-* 2>/dev/null || true
fi

# ── Конфигурация из переменных окружения ─────────────────────────────────────

# Переменные PANEL_URL и API_KEY могут быть переданы при запуске:
#   PANEL_URL=https://... API_KEY=xxx curl ... | sh

if [ -n "${PANEL_URL:-}" ]; then
  uci set dpi-rip-node.settings.panel_url="$PANEL_URL"
fi

if [ -n "${API_KEY:-}" ]; then
  uci set dpi-rip-node.settings.api_key="$API_KEY"
fi

if [ -n "${PANEL_URL:-}" ] || [ -n "${API_KEY:-}" ]; then
  uci commit dpi-rip-node
fi

# ── Сервис ────────────────────────────────────────────────────────────────────

step "Enabling service"

/etc/init.d/dpi-rip-node disable 2>/dev/null || true

CONFIGURED_URL=$(uci -q get dpi-rip-node.settings.panel_url 2>/dev/null || true)

if [ -z "$CONFIGURED_URL" ]; then
  warn "panel_url not configured — service will start after setup"
else
  /etc/init.d/dpi-rip-node enable
  /etc/init.d/dpi-rip-node start
  ok "Service enabled and started"
fi

# ── Готово ────────────────────────────────────────────────────────────────────

printf "\n\033[1;32mInstallation complete!\033[0m\n\n"

if [ -z "$CONFIGURED_URL" ]; then
  if [ "$LUCI_AVAILABLE" = "true" ]; then
    printf "  Open LuCI: Services → DPI-RIP Node\n\n"
  else
    printf "  uci set dpi-rip-node.settings.panel_url='https://YOUR_PANEL'\n"
    printf "  uci set dpi-rip-node.settings.api_key='YOUR_API_KEY'\n"
    printf "  uci commit dpi-rip-node\n"
    printf "  /etc/init.d/dpi-rip-node enable && /etc/init.d/dpi-rip-node start\n\n"
  fi
else
  printf "  Status : /usr/sbin/dpi-rip-node status\n"
  printf "  Logs   : logread | grep dpi-rip\n"
  printf "  Run    : /usr/sbin/dpi-rip-node check\n\n"
fi
