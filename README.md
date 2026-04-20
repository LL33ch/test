# dpi-rip-node

Агент мониторинга интернет-ограничений для роутеров на OpenWRT.

## Установка

```sh
PANEL_URL=https://your-panel.com API_KEY=your-api-key \
  curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh
```

Или без параметров — настроить потом через LuCI (**Services → DPI-RIP Node**):

```sh
curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh
```

## Удаление

```sh
curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/uninstall.sh | sh
```
