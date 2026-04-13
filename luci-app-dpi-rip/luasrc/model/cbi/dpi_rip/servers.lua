local m, s, o
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

m = Map("dpi-rip", "DPI-RIP — " .. translate("Servers"))

-- ====================================================
-- Секция: добавить сервер по ссылке
-- ====================================================
s = m:section(NamedSection, "main", "main", translate("Add Server"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "pending_link", translate("Paste link"))
o.placeholder = "vless://...  or  vmess://...  or  trojan://...  or  ss://..."
o.rmempty = true

o = s:option(Value, "pending_name", translate("Name (optional)"))
o.rmempty = true

-- При сохранении — парсим ссылку и создаём секцию server
function m.on_commit(map)
    local link = uci:get("dpi-rip", "main", "pending_link") or ""
    link = link:gsub("^%s+", ""):gsub("%s+$", "")

    if link ~= "" then
        local name = uci:get("dpi-rip", "main", "pending_name") or ""

        -- Определяем протокол
        local proto = "unknown"
        if     link:match("^vless://")   then proto = "vless"
        elseif link:match("^vmess://")   then proto = "vmess"
        elseif link:match("^trojan://")  then proto = "trojan"
        elseif link:match("^ss://")      then proto = "shadowsocks"
        elseif link:match("^hy2://") or
               link:match("^hysteria2://") then proto = "hysteria2"
        end

        -- Имя из фрагмента ссылки (#...)
        if name == "" then
            local frag = link:match("#(.+)$")
            if frag then
                name = frag:gsub("%%(%x%x)", function(h)
                    return string.char(tonumber(h, 16))
                end)
            end
            if name == "" then name = proto .. "_" .. os.time() end
        end

        local sid = "server_" .. os.time()
        uci:set("dpi-rip", sid, "server")
        uci:set("dpi-rip", sid, "name",     name)
        uci:set("dpi-rip", sid, "link",     link)
        uci:set("dpi-rip", sid, "protocol", proto)

        -- Очищаем временные поля
        uci:delete("dpi-rip", "main", "pending_link")
        uci:delete("dpi-rip", "main", "pending_name")
        uci:save("dpi-rip")
        uci:commit("dpi-rip")
    end
end

-- ====================================================
-- Секция: список серверов
-- ====================================================
s = m:section(TypedSection, "server", translate("Server List"))
s.anonymous = false
s.addremove = true
s.template  = "cbi/tblsection"

o = s:option(DummyValue, "name", translate("Name"))

o = s:option(DummyValue, "protocol", translate("Protocol"))

o = s:option(DummyValue, "link", translate("Link"))
o.cfgvalue = function(self, section)
    local v = self.map:get(section, "link") or ""
    -- Показываем только первые 60 символов
    if #v > 60 then v = v:sub(1, 60) .. "…" end
    return v
end

-- Активный сервер
o = s:option(DummyValue, "_active", translate("Status"))
o.rawhtml = true
o.cfgvalue = function(self, section)
    local active = uci:get("dpi-rip", "main", "active_server") or ""
    if active == section then
        return "<strong>&#9654; " .. translate("Active") .. "</strong>"
    end
    return "—"
end

return m
