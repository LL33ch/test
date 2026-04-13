#!/usr/bin/env python3
"""
DPI-RIP: загрузка подписки.
Сохраняет серверы в /etc/dpi-rip/servers.json
и мета-информацию в /etc/dpi-rip/sub-info.json
"""
import urllib.request, json, base64, subprocess, sys, os
from datetime import datetime, timezone

SERVERS_FILE = "/etc/dpi-rip/servers.json"
INFO_FILE    = "/etc/dpi-rip/sub-info.json"

def uci(key):
    try:
        return subprocess.check_output(
            ["uci", "-q", "get", key],
            stderr=subprocess.DEVNULL
        ).decode().strip()
    except:
        return ""

def fmt_bytes(n):
    n = int(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:.2f} {unit}"
        n /= 1024
    return f"{n:.2f} PB"

def main():
    sub_url = uci("dpi-rip.main.sub_url")
    if not sub_url:
        print("DPI-RIP: sub_url not set", file=sys.stderr)
        sys.exit(1)

    os.makedirs("/etc/dpi-rip", exist_ok=True)

    print(f"DPI-RIP: fetching {sub_url}")
    req = urllib.request.Request(sub_url, headers={"User-Agent": "Happ/"})

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            # Читаем заголовки (регистронезависимо)
            hdrs = {k.lower(): v for k, v in resp.headers.items()}
            body = resp.read().decode("utf-8")
    except Exception as e:
        print(f"DPI-RIP: fetch error: {e}", file=sys.stderr)
        sys.exit(1)

    # --- profile-title ---
    raw_title = hdrs.get("profile-title", "")
    if raw_title.lower().startswith("base64:"):
        try:
            title = base64.b64decode(raw_title[7:]).decode("utf-8")
        except Exception:
            title = raw_title
    else:
        title = raw_title

    # --- subscription-userinfo ---
    info_str = hdrs.get("subscription-userinfo", "")
    info = {}
    for part in info_str.split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            info[k.strip()] = v.strip()

    upload   = int(info.get("upload",   0))
    download = int(info.get("download", 0))
    total    = int(info.get("total",    0))
    expire   = int(info.get("expire",   0))

    # Форматируем дату истечения
    expire_str = ""
    if expire > 0:
        try:
            dt = datetime.fromtimestamp(expire, tz=timezone.utc)
            expire_str = dt.strftime("%Y-%m-%d")
        except Exception:
            expire_str = str(expire)

    # Считаем использование
    used_bytes = upload + download
    used_pct   = 0
    if total > 0:
        used_pct = round(used_bytes / total * 100, 1)

    sub_info = {
        "title":       title,
        "upload":      upload,
        "download":    download,
        "total":       total,
        "expire":      expire,
        "expire_str":  expire_str,
        "used_fmt":    fmt_bytes(used_bytes),
        "total_fmt":   fmt_bytes(total) if total > 0 else "∞",
        "used_pct":    used_pct,
    }

    # --- Сохраняем ---
    with open(INFO_FILE, "w", encoding="utf-8") as f:
        json.dump(sub_info, f, ensure_ascii=False, indent=2)

    servers = json.loads(body)
    with open(SERVERS_FILE, "w", encoding="utf-8") as f:
        json.dump(servers, f, ensure_ascii=False, indent=2)

    print(f"DPI-RIP: OK — {len(servers)} servers | {title or '(no title)'}")
    if expire_str:
        print(f"         expires: {expire_str} | used: {fmt_bytes(used_bytes)} / {fmt_bytes(total) if total > 0 else '∞'}")

if __name__ == "__main__":
    main()
