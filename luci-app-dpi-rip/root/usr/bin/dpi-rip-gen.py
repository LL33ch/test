#!/usr/bin/env python3
"""
DPI-RIP: генератор xray конфига из подписки.
Берёт готовый config из servers.json, адаптирует inbounds для роутера.
"""
import json, subprocess, sys, os

SERVERS_FILE = "/etc/dpi-rip/servers.json"
CONFIG_FILE  = "/etc/dpi-rip/config.json"
TPROXY_PORT  = 7892

def uci(key):
    try:
        return subprocess.check_output(["uci", "-q", "get", key],
                                       stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ""

def main():
    active_remarks = uci("dpi-rip.main.active_remarks")
    proxy_mode     = uci("dpi-rip.main.proxy_mode") or "tproxy"

    if not os.path.exists(SERVERS_FILE):
        print("DPI-RIP: servers.json not found, run dpi-rip-fetch.sh first", file=sys.stderr)
        sys.exit(1)

    with open(SERVERS_FILE, encoding="utf-8") as f:
        servers = json.load(f)

    # Ищем сервер по remarks
    config = None
    for srv in servers:
        if srv.get("remarks", "") == active_remarks:
            config = srv
            break

    # Если не найден — берём первый
    if config is None:
        if not servers:
            print("DPI-RIP: server list is empty", file=sys.stderr)
            sys.exit(1)
        config = servers[0]
        print(f"DPI-RIP: server '{active_remarks}' not found, using first server", file=sys.stderr)

    # Делаем глубокую копию чтобы не менять оригинал
    import copy
    config = copy.deepcopy(config)

    # Убираем поле remarks (не является частью xray конфига)
    config.pop("remarks", None)

    # --- Адаптируем inbounds для роутера ---
    # Меняем listen с 127.0.0.1 на 0.0.0.0 — доступно из LAN
    for inbound in config.get("inbounds", []):
        inbound["listen"] = "0.0.0.0"

    # Добавляем tproxy inbound для перехвата LAN трафика
    if proxy_mode == "tproxy":
        config["inbounds"].append({
            "tag": "tproxy-in",
            "port": TPROXY_PORT,
            "protocol": "dokodemo-door",
            "settings": {
                "network": "tcp,udp",
                "followRedirect": True
            },
            "sniffing": {
                "enabled": True,
                "destOverride": ["http", "tls", "quic"]
            },
            "streamSettings": {
                "sockopt": {"tproxy": "tproxy"}
            }
        })

        # Добавляем правило маршрутизации для tproxy трафика
        routing = config.setdefault("routing", {})
        rules   = routing.setdefault("rules", [])
        rules.insert(0, {
            "type": "field",
            "inboundTag": ["tproxy-in"],
            "outboundTag": "proxy"
        })

    # Добавляем лог
    config.setdefault("log", {
        "loglevel": "warning",
        "error":    "/var/log/dpi-rip-error.log",
        "access":   "/var/log/dpi-rip-access.log"
    })

    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    print(f"DPI-RIP: config written → {CONFIG_FILE}")

if __name__ == "__main__":
    main()
