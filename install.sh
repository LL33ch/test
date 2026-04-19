#!/bin/sh
#
# Установка dpi-rip-node на OpenWRT
# Запускается прямо на роутере:
#
#   curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh

set -eu

REPO_RAW="https://raw.githubusercontent.com/LL33ch/test/refs/heads/main"
PKG="dpi-rip-node"

# ── Вывод ─────────────────────────────────────────────────────────────────────

step() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[0;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\n\033[0;31m✗ %s\033[0m\n\n" "$*" >&2; exit 1; }

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

# ── Утилита скачивания с прогресс-баром ──────────────────────────────────────

# download URL DST — скачивает файл, показывает спиннер и итоговый размер
download() {
  local url="$1" dst="$2"
  local name spin_pid bytes size_str

  name="$(basename "$dst")"
  mkdir -p "$(dirname "$dst")"

  # Спиннер: обновляется раз в секунду (busybox sleep принимает только целые)
  (
    i=0
    while true; do
      case $((i % 4)) in
        0) c='|' ;; 1) c='/' ;; 2) c='-' ;; 3) c='\' ;;
      esac
      printf "\r  \033[0;36m%s\033[0m %-38s" "$c" "$name"
      i=$((i + 1))
      sleep 1
    done
  ) &
  spin_pid=$!

  wget -qO "$dst" "$url" 2>/dev/null
  local rc=$?

  kill "$spin_pid" 2>/dev/null
  wait "$spin_pid" 2>/dev/null

  if [ "$rc" -ne 0 ]; then
    printf "\r  \033[0;31m✗\033[0m %-38s \033[0;31m[FAILED]\033[0m\n" "$name"
    die "Cannot download: $name"
  fi

  bytes=$(wc -c < "$dst" 2>/dev/null || echo 0)

  if   [ "$bytes" -ge 1048576 ]; then
    size_str=$(awk "BEGIN{printf \"%.1f MB\",$bytes/1048576}")
  elif [ "$bytes" -ge 1024 ]; then
    size_str=$(awk "BEGIN{printf \"%.1f KB\",$bytes/1024}")
  else
    size_str="${bytes} B"
  fi

  printf "\r  \033[0;32m✓\033[0m %-38s \033[1m[####################]\033[0m %s\n" \
    "$name" "$size_str"
}

# ── Скачивание файлов ─────────────────────────────────────────────────────────

step "Downloading package files"

mkdir -p /etc/config /etc/init.d /etc/hotplug.d/iface /usr/sbin

download "${REPO_RAW}/${PKG}/files/usr/sbin/dpi-rip-node"               /usr/sbin/dpi-rip-node
download "${REPO_RAW}/${PKG}/files/etc/init.d/dpi-rip-node"             /etc/init.d/dpi-rip-node
download "${REPO_RAW}/${PKG}/files/etc/hotplug.d/iface/30-dpi-rip-node" /etc/hotplug.d/iface/30-dpi-rip-node

# Конфиг не перезаписываем если уже есть (защита настроек при обновлении)
if [ ! -f /etc/config/dpi-rip-node ]; then
  download "${REPO_RAW}/${PKG}/files/etc/config/dpi-rip-node" /etc/config/dpi-rip-node
else
  warn "Config already exists — skipped (settings preserved)"
fi

# ── LuCI интерфейс ────────────────────────────────────────────────────────────

LUCI_PKG="luci-app-dpi-rip-node"

LUCI_AVAILABLE=false
if opkg list-installed 2>/dev/null | grep -q "^luci "; then
  LUCI_AVAILABLE=true
fi

if [ "$LUCI_AVAILABLE" = "true" ]; then
  step "Installing LuCI interface"

  download "${REPO_RAW}/${LUCI_PKG}/htdocs/luci-static/resources/view/dpi-rip-node/settings.js" \
           /www/luci-static/resources/view/dpi-rip-node/settings.js

  download "${REPO_RAW}/${LUCI_PKG}/root/usr/share/luci/menu.d/luci-app-dpi-rip-node.json" \
           /usr/share/luci/menu.d/luci-app-dpi-rip-node.json

  download "${REPO_RAW}/${LUCI_PKG}/root/usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json" \
           /usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json

  download "${REPO_RAW}/${LUCI_PKG}/root/usr/libexec/rpcd/dpi-rip-node" \
           /usr/libexec/rpcd/dpi-rip-node

  chmod 755 /usr/libexec/rpcd/dpi-rip-node

  # Перезапускаем rpcd чтобы он подхватил новый ACL и плагин
  /etc/init.d/rpcd restart 2>/dev/null || true

  # Сбрасываем кэш LuCI
  rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-* 2>/dev/null || true

  ok "LuCI interface ready  →  Services › DPI-RIP Node"
else
  warn "LuCI not detected — skipping web interface"
fi

# ── Права ─────────────────────────────────────────────────────────────────────

step "Setting permissions"

chmod 755 /usr/sbin/dpi-rip-node
chmod 755 /etc/init.d/dpi-rip-node
chmod 755 /etc/hotplug.d/iface/30-dpi-rip-node
chmod 600 /etc/config/dpi-rip-node

ok "Permissions set"

# ── Сервис ────────────────────────────────────────────────────────────────────

step "Enabling service"

/etc/init.d/dpi-rip-node disable 2>/dev/null || true

PANEL_URL=$(uci -q get dpi-rip-node.settings.panel_url 2>/dev/null || true)

if [ -z "$PANEL_URL" ]; then
  warn "panel_url not configured — service will start after setup"
else
  /etc/init.d/dpi-rip-node enable
  /etc/init.d/dpi-rip-node start
  ok "Service enabled and started"
fi

# ── Готово ────────────────────────────────────────────────────────────────────

printf "\n\033[1;32mInstallation complete!\033[0m\n\n"

if [ -z "$PANEL_URL" ]; then
  if [ "$LUCI_AVAILABLE" = "true" ]; then
    printf "Open LuCI: Services → DPI-RIP Node\n\n"
  else
    printf "Configure the node:\n\n"
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
