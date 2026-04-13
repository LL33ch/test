-- LuCI Controller: DPI-RIP
-- Маршруты и AJAX-endpoints для luci-app-dpi-rip

module("luci.controller.dpi_rip", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/dpi-rip") then return end

    local page = entry(
        {"admin", "services", "dpi-rip"},
        alias("admin", "services", "dpi-rip", "overview"),
        _("DPI-RIP"), 60
    )
    page.dependent = true
    page.acl_depends = { "luci-app-dpi-rip" }

    -- Страницы
    entry({"admin", "services", "dpi-rip", "overview"},
        cbi("dpi_rip/overview"), _("Overview"), 10)

    entry({"admin", "services", "dpi-rip", "servers"},
        cbi("dpi_rip/servers"), _("Servers"), 20)

    entry({"admin", "services", "dpi-rip", "log"},
        template("dpi_rip/log"), _("Log"), 30)

    -- AJAX endpoints (leaf = не показываются в меню)
    entry({"admin", "services", "dpi-rip", "status"},
        call("action_status")).leaf = true

    entry({"admin", "services", "dpi-rip", "add_server"},
        call("action_add_server")).leaf = true

    entry({"admin", "services", "dpi-rip", "del_server"},
        call("action_del_server")).leaf = true

    entry({"admin", "services", "dpi-rip", "set_active"},
        call("action_set_active")).leaf = true

    entry({"admin", "services", "dpi-rip", "get_log"},
        call("action_get_log")).leaf = true

    entry({"admin", "services", "dpi-rip", "toggle"},
        call("action_toggle")).leaf = true

    entry({"admin", "services", "dpi-rip", "list_servers"},
        call("action_list_servers")).leaf = true

    entry({"admin", "services", "dpi-rip", "clear_log"},
        call("action_clear_log")).leaf = true
end

function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()

    local pid = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
    local enabled     = uci:get("dpi-rip", "main", "enabled") or "0"
    local active      = uci:get("dpi-rip", "main", "active_server") or ""
    local server_name = ""
    if active ~= "" then
        server_name = uci:get("dpi-rip", active, "name") or active
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        running       = (pid ~= "" and pid ~= nil),
        enabled       = (enabled == "1"),
        pid           = pid,
        active_server = active,
        server_name   = server_name,
    })
end

function action_add_server()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()

    local link = (http.formvalue("link") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local name = http.formvalue("name") or ""

    if link == "" then
        http.prepare_content("application/json")
        http.write_json({ ok = false, error = "Empty link" })
        return
    end

    local proto = detect_protocol(link)
    if not proto then
        http.prepare_content("application/json")
        http.write_json({ ok = false, error = "Unsupported protocol" })
        return
    end

    if name == "" then
        name = extract_name(link) or (proto .. "_server")
    end

    local sid = "server_" .. os.time()
    uci:set("dpi-rip", sid, "server")
    uci:set("dpi-rip", sid, "name",     name)
    uci:set("dpi-rip", sid, "link",     link)
    uci:set("dpi-rip", sid, "protocol", proto)
    uci:set("dpi-rip", sid, "added",    tostring(os.time()))
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    http.prepare_content("application/json")
    http.write_json({ ok = true, id = sid, name = name, protocol = proto })
end

function action_del_server()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()

    local sid = http.formvalue("id") or ""
    if sid == "" then
        http.prepare_content("application/json")
        http.write_json({ ok = false, error = "No id" })
        return
    end

    local active = uci:get("dpi-rip", "main", "active_server") or ""
    if active == sid then
        uci:set("dpi-rip", "main", "active_server", "")
    end

    uci:delete("dpi-rip", sid)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

function action_set_active()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local sid = http.formvalue("id") or ""
    uci:set("dpi-rip", "main", "active_server", sid)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    sys.exec("/etc/init.d/dpi-rip restart &")

    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

function action_toggle()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local enabled = uci:get("dpi-rip", "main", "enabled") or "0"
    local new_val = (enabled == "1") and "0" or "1"

    uci:set("dpi-rip", "main", "enabled", new_val)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    if new_val == "1" then
        sys.exec("/etc/init.d/dpi-rip start &")
    else
        sys.exec("/etc/init.d/dpi-rip stop &")
    end

    http.prepare_content("application/json")
    http.write_json({ ok = true, enabled = (new_val == "1") })
end

function action_get_log()
    local http = require "luci.http"
    local sys  = require "luci.sys"

    local log_type = http.formvalue("type") or "error"
    local lines    = tonumber(http.formvalue("lines")) or 100
    local logfile  = (log_type == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"

    local content = sys.exec(string.format("tail -n %d %s 2>/dev/null", lines, logfile))

    http.prepare_content("application/json")
    http.write_json({ ok = true, content = content })
end

-- Список всех серверов из UCI
function action_list_servers()
    local uci  = require "luci.model.uci".cursor()
    local http = require "luci.http"

    local servers = {}
    uci:foreach("dpi-rip", "server", function(s)
        servers[#servers + 1] = {
            id       = s[".name"],
            name     = s.name     or s[".name"],
            protocol = s.protocol or "unknown",
            added    = s.added    or "",
        }
    end)

    -- Сортируем по времени добавления (новые внизу)
    table.sort(servers, function(a, b)
        return (tonumber(a.added) or 0) < (tonumber(b.added) or 0)
    end)

    http.prepare_content("application/json")
    http.write_json({ ok = true, servers = servers })
end

-- Очистить лог-файл
function action_clear_log()
    local http = require "luci.http"
    local sys  = require "luci.sys"

    local log_type = http.formvalue("type") or "error"
    local logfile  = (log_type == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"

    sys.exec("> " .. logfile .. " 2>/dev/null")

    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

-- Вспомогательные

function detect_protocol(link)
    if link:match("^vless://")               then return "vless"       end
    if link:match("^vmess://")               then return "vmess"       end
    if link:match("^trojan://")              then return "trojan"      end
    if link:match("^ss://")                  then return "shadowsocks" end
    if link:match("^hy2://") or
       link:match("^hysteria2://")           then return "hysteria2"   end
    return nil
end

function extract_name(link)
    local name = link:match("#(.+)$")
    if name then
        name = name:gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end)
    end
    return name
end
