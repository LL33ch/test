#!/bin/bash
#
# Установка dpi-rip-node на роутер с OpenWRT
#
# Использование:
#   ./install.sh [ROUTER_IP] [SSH_USER]
#
# Примеры:
#   ./install.sh                      # 192.168.1.1, root
#   ./install.sh 10.0.0.1
#   ./install.sh 10.0.0.1 admin

set -euo pipefail

# ── Параметры ──────────────────────────────────────────────────────────────────

ROUTER="${1:-192.168.1.1}"
SSH_USER="${2:-root}"
PKG_DIR="$(cd "$(dirname "$0")/dpi-rip-node" && pwd)"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"
SSH="${SSH_USER}@${ROUTER}"

# ── Цвета ──────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}!${RESET} $*"; }
die()   { echo -e "\n${RED}${BOLD}✗ $*${RESET}\n" >&2; exit 1; }

# ── Проверка окружения ─────────────────────────────────────────────────────────

step "Checking prerequisites"

command -v ssh  >/dev/null || die "ssh not found"
command -v scp  >/dev/null || die "scp not found"

[ -d "$PKG_DIR/files" ] || die "Package directory not found: $PKG_DIR/files"
ok "Package directory: $PKG_DIR"

# ── Проверка подключения к роутеру ────────────────────────────────────────────

step "Connecting to ${SSH} ..."

ssh $SSH_OPTS "$SSH" "echo ok" >/dev/null 2>&1 \
  || die "Cannot connect to ${SSH}. Check IP, SSH key / password, and that router is reachable."

ok "Connected to $ROUTER"

ROUTER_OS=$(ssh $SSH_OPTS "$SSH" "cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_ID | cut -d= -f2 | tr -d '\"'" 2>/dev/null || true)
[ -n "$ROUTER_OS" ] || die "This doesn't look like an OpenWRT device"
ok "OS: $ROUTER_OS"

# ── Установка зависимостей ────────────────────────────────────────────────────

step "Checking dependencies on router"

ssh $SSH_OPTS "$SSH" bash <<'REMOTE'
  MISSING=""
  for pkg in curl jsonfilter; do
    if ! opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
      MISSING="$MISSING $pkg"
    fi
  done

  if [ -n "$MISSING" ]; then
    echo "Installing:$MISSING"
    opkg update -q 2>/dev/null || true
    opkg install $MISSING || { echo "ERR: opkg install failed"; exit 1; }
  else
    echo "OK: all deps present"
  fi
REMOTE

ok "Dependencies satisfied"

# ── Остановка сервиса (если запущен) ─────────────────────────────────────────

step "Stopping existing service (if running)"
ssh $SSH_OPTS "$SSH" \
  "/etc/init.d/dpi-rip-node stop 2>/dev/null; /etc/init.d/dpi-rip-node disable 2>/dev/null; true" \
  >/dev/null 2>&1 || true
ok "Service stopped"

# ── Копирование файлов ────────────────────────────────────────────────────────

step "Copying package files"

# Создаём директории на роутере
ssh $SSH_OPTS "$SSH" \
  "mkdir -p /etc/config /etc/init.d /etc/hotplug.d/iface /usr/sbin"

# Копируем файлы через scp
scp $SSH_OPTS \
  "$PKG_DIR/files/etc/init.d/dpi-rip-node" \
  "${SSH}:/etc/init.d/dpi-rip-node"

scp $SSH_OPTS \
  "$PKG_DIR/files/etc/hotplug.d/iface/30-dpi-rip-node" \
  "${SSH}:/etc/hotplug.d/iface/30-dpi-rip-node"

scp $SSH_OPTS \
  "$PKG_DIR/files/usr/sbin/dpi-rip-node" \
  "${SSH}:/usr/sbin/dpi-rip-node"

# UCI конфиг — копируем только если ещё нет (не перезатираем настройки)
CONFIG_EXISTS=$(ssh $SSH_OPTS "$SSH" \
  "[ -f /etc/config/dpi-rip-node ] && echo yes || echo no" 2>/dev/null)

if [ "$CONFIG_EXISTS" = "no" ]; then
  scp $SSH_OPTS \
    "$PKG_DIR/files/etc/config/dpi-rip-node" \
    "${SSH}:/etc/config/dpi-rip-node"
  ok "Config installed (first time)"
else
  warn "Config already exists — skipped (use --reset-config to overwrite)"
fi

ok "Files copied"

# ── Выставляем права ──────────────────────────────────────────────────────────

step "Setting permissions"
ssh $SSH_OPTS "$SSH" bash <<'REMOTE'
  chmod 755 /etc/init.d/dpi-rip-node
  chmod 755 /etc/hotplug.d/iface/30-dpi-rip-node
  chmod 755 /usr/sbin/dpi-rip-node
  chmod 600 /etc/config/dpi-rip-node
REMOTE
ok "Permissions set"

# ── Включаем и запускаем сервис ───────────────────────────────────────────────

step "Enabling service"

PANEL_URL=$(ssh $SSH_OPTS "$SSH" \
  "uci -q get dpi-rip-node.settings.panel_url || true" 2>/dev/null)

if [ -z "$PANEL_URL" ]; then
  warn "panel_url is not set — service will NOT start until configured"
  warn ""
  warn "Configure on the router:"
  warn "  ssh ${SSH}"
  warn "  uci set dpi-rip-node.settings.panel_url='https://YOUR_PANEL'"
  warn "  uci set dpi-rip-node.settings.api_key='YOUR_KEY'"
  warn "  uci commit dpi-rip-node"
  warn "  /etc/init.d/dpi-rip-node enable && /etc/init.d/dpi-rip-node start"
else
  ssh $SSH_OPTS "$SSH" \
    "/etc/init.d/dpi-rip-node enable && /etc/init.d/dpi-rip-node start"
  ok "Service enabled and started"
fi

# ── Итог ─────────────────────────────────────────────────────────────────────

echo
echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
echo
echo -e "  Router     : ${CYAN}${ROUTER}${RESET}"
echo -e "  SSH        : ${CYAN}${SSH}${RESET}"
echo -e "  Status     : ssh ${SSH} '/usr/sbin/dpi-rip-node status'"
echo -e "  Logs       : ssh ${SSH} 'logread | grep dpi-rip'"
echo -e "  Manual run : ssh ${SSH} '/usr/sbin/dpi-rip-node check'"
echo
