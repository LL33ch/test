# dpi-rip-node

Агент мониторинга интернет-ограничений для роутеров на OpenWRT.

## Установка

```sh
curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh -s -- --panel-url=https://your-panel.com --api-key=your-api-key
```

Или без параметров — настроить потом через LuCI (**Services → DPI-RIP Node**):

```sh
curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/install.sh | sh
```

## Удаление

```sh
curl -fsSL https://raw.githubusercontent.com/LL33ch/test/refs/heads/main/uninstall.sh | sh
```
