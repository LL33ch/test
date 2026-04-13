-- LuCI CBI: DPI-RIP — список серверов
-- Динамическая таблица с кнопкой "Активировать" и удалением

local m, s, o
local uci = require "luci.model.uci".cursor()

m = Map("dpi-rip", translate("DPI-RIP — Servers"))

-- ====================================================
-- Секция: добавить сервер по ссылке
-- ====================================================
s = m:section(TypedSection, "_add", translate("Add Server"))
s.template = "dpi_rip/add_server"   -- кастомный шаблон с textarea

-- ====================================================
-- Секция: список серверов
-- ====================================================
s = m:section(TypedSection, "server", translate("Server List"))
s.anonymous = false
s.addremove = false   -- удаление через кастомную кнопку в шаблоне
s.template  = "dpi_rip/server_list"

o = s:option(DummyValue, "name", translate("Name"))
o = s:option(DummyValue, "protocol", translate("Protocol"))

-- Статус активности
o = s:option(DummyValue, "_active", translate("Status"))
o.rawhtml = true
o.cfgvalue = function(self, section)
    local active = uci:get("dpi-rip", "main", "active_server") or ""
    if active == section then
        return '<span class="label success">' .. translate("Active") .. '</span>'
    else
        return '<span class="label">' .. translate("Inactive") .. '</span>'
    end
end

return m
