-- LuCI CBI: DPI-RIP Overview

local m, s, o

m = Map("dpi-rip", translate("DPI-RIP"),
    translate("Transparent proxy based on Xray-core. Supports VLESS, VMess, Trojan, Shadowsocks."))

s = m:section(NamedSection, "main", "main", translate("General Settings"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

o = s:option(ListValue, "proxy_mode", translate("Proxy Mode"))
o:value("tproxy", translate("Transparent Proxy (TProxy) — all LAN traffic"))
o:value("socks",  translate("SOCKS5 redirect"))
o.default = "tproxy"

o = s:option(Flag, "bypass_cn", translate("Bypass CN traffic (direct)"))
o.rmempty = false
o.default = "1"

o = s:option(ListValue, "dns_mode", translate("DNS Mode"))
o:value("doh",   translate("DNS over HTTPS (1.1.1.1 / 114.114.114.114)"))
o:value("plain", translate("Plain DNS (1.1.1.1, 8.8.8.8)"))
o.default = "doh"

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("none",    "None")
o:value("error",   "Error")
o:value("warning", "Warning")
o:value("info",    "Info")
o:value("debug",   "Debug")
o.default = "warning"

return m
