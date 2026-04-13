local m, s, o
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

-- Статус xray в заголовок
local pid = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
local status_str = (pid ~= "") and "● Running (PID: " .. pid .. ")" or "○ Stopped"

m = Map("dpi-rip", "DPI-RIP",
    translate(status_str))

-- ====================================================
-- Секция: основные настройки
-- ====================================================
s = m:section(NamedSection, "main", "main", translate("General"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

-- Активный сервер — выбор из добавленных
o = s:option(ListValue, "active_server", translate("Active Server"))
o:value("", translate("-- not selected --"))
uci:foreach("dpi-rip", "server", function(sv)
    o:value(sv[".name"], sv.name or sv[".name"])
end)

o = s:option(ListValue, "proxy_mode", translate("Proxy Mode"))
o:value("tproxy", translate("Transparent Proxy (TProxy)"))
o:value("socks",  translate("SOCKS5 Redirect"))
o.default = "tproxy"

o = s:option(Flag, "bypass_cn", translate("Bypass CN traffic (direct)"))
o.rmempty = false
o.default = "1"

o = s:option(ListValue, "dns_mode", translate("DNS Mode"))
o:value("doh",   translate("DNS over HTTPS (1.1.1.1)"))
o:value("plain", translate("Plain DNS (1.1.1.1, 8.8.8.8)"))
o.default = "doh"

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("none",    "None")
o:value("error",   "Error")
o:value("warning", "Warning")
o:value("info",    "Info")
o:value("debug",   "Debug")
o.default = "warning"

-- Перезапуск после сохранения
function m.on_commit(map)
    sys.exec("/etc/init.d/dpi-rip restart &")
end

return m
