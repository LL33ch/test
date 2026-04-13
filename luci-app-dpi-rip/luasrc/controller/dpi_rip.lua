-- DPI-RIP LuCI Controller
-- Использует только call() + template() — работает на любой версии OpenWRT
-- Никаких зависимостей от luci.cbi или luci-compat

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

    entry({"admin", "services", "dpi-rip", "overview"},
        call("action_overview"), _("Overview"), 10)

    entry({"admin", "services", "dpi-rip", "servers"},
        call("action_servers"), _("Servers"), 20)

    entry({"admin", "services", "dpi-rip", "log"},
        call("action_log"), _("Log"), 30)

    -- AJAX endpoints
    entry({"admin", "services", "dpi-rip", "status"},
        call("action_status")).leaf = true

    entry({"admin", "services", "dpi-rip", "toggle"},
        call("action_toggle")).leaf = true

    entry({"admin", "services", "dpi-rip", "add_server"},
        call("action_add_server")).leaf = true

    entry({"admin", "services", "dpi-rip", "del_server"},
        call("action_del_server")).leaf = true

    entry({"admin", "services", "dpi-rip", "set_active"},
        call("action_set_active")).leaf = true

    entry({"admin", "services", "dpi-rip", "get_log"},
        call("action_get_log")).leaf = true

    entry({"admin", "services", "dpi-rip", "clear_log"},
        call("action_clear_log")).leaf = true
end

-- ================================================================
-- Overview: настройки + статус
-- ================================================================
function action_overview()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    if http.getenv("REQUEST_METHOD") == "POST" then
        local enabled    = http.formvalue("enabled")    or "0"
        local proxy_mode = http.formvalue("proxy_mode") or "tproxy"
        local bypass_cn  = http.formvalue("bypass_cn")  or "0"
        local dns_mode   = http.formvalue("dns_mode")   or "doh"
        local log_level  = http.formvalue("log_level")  or "warning"
        local active_srv = http.formvalue("active_server") or ""

        uci:set("dpi-rip", "main", "enabled",       enabled)
        uci:set("dpi-rip", "main", "proxy_mode",    proxy_mode)
        uci:set("dpi-rip", "main", "bypass_cn",     bypass_cn)
        uci:set("dpi-rip", "main", "dns_mode",      dns_mode)
        uci:set("dpi-rip", "main", "log_level",     log_level)
        uci:set("dpi-rip", "main", "active_server", active_srv)
        uci:save("dpi-rip")
        uci:commit("dpi-rip")

        sys.exec("/etc/init.d/dpi-rip restart &")
        http.redirect(luci.dispatcher.build_url("admin", "services", "dpi-rip", "overview"))
        return
    end

    -- Собираем данные для шаблона
    local cfg = {
        enabled       = uci:get("dpi-rip", "main", "enabled")       or "0",
        proxy_mode    = uci:get("dpi-rip", "main", "proxy_mode")    or "tproxy",
        bypass_cn     = uci:get("dpi-rip", "main", "bypass_cn")     or "1",
        dns_mode      = uci:get("dpi-rip", "main", "dns_mode")      or "doh",
        log_level     = uci:get("dpi-rip", "main", "log_level")     or "warning",
        active_server = uci:get("dpi-rip", "main", "active_server") or "",
    }

    local pid = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
    cfg.running = (pid ~= "")
    cfg.pid = pid

    -- Список серверов для select
    local servers = {}
    uci:foreach("dpi-rip", "server", function(s)
        servers[#servers + 1] = {
            id   = s[".name"],
            name = s.name or s[".name"],
        }
    end)
    cfg.servers = servers

    luci.template.render("dpi_rip/overview", { cfg = cfg })
end

-- ================================================================
-- Servers: список + добавление
-- ================================================================
function action_servers()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()

    if http.getenv("REQUEST_METHOD") == "POST" then
        local action = http.formvalue("action") or ""

        if action == "add" then
            local link = (http.formvalue("link") or ""):gsub("^%s+", ""):gsub("%s+$", "")
            local name = http.formvalue("name") or ""

            if link ~= "" then
                local proto = detect_protocol(link)
                if name == "" then
                    name = extract_name(link) or ((proto or "unknown") .. "_" .. os.time())
                end
                local sid = "server_" .. os.time()
                uci:set("dpi-rip", sid, "server")
                uci:set("dpi-rip", sid, "name",     name)
                uci:set("dpi-rip", sid, "link",     link)
                uci:set("dpi-rip", sid, "protocol", proto or "unknown")
                uci:save("dpi-rip")
                uci:commit("dpi-rip")
            end

        elseif action == "delete" then
            local sid = http.formvalue("id") or ""
            if sid ~= "" then
                local active = uci:get("dpi-rip", "main", "active_server") or ""
                if active == sid then
                    uci:set("dpi-rip", "main", "active_server", "")
                end
                uci:delete("dpi-rip", sid)
                uci:save("dpi-rip")
                uci:commit("dpi-rip")
            end

        elseif action == "activate" then
            local sid = http.formvalue("id") or ""
            uci:set("dpi-rip", "main", "active_server", sid)
            uci:save("dpi-rip")
            uci:commit("dpi-rip")
            local sys = require "luci.sys"
            sys.exec("/etc/init.d/dpi-rip restart &")
        end

        http.redirect(luci.dispatcher.build_url("admin", "services", "dpi-rip", "servers"))
        return
    end

    local servers = {}
    local active = uci:get("dpi-rip", "main", "active_server") or ""
    uci:foreach("dpi-rip", "server", function(s)
        servers[#servers + 1] = {
            id       = s[".name"],
            name     = s.name     or s[".name"],
            protocol = s.protocol or "unknown",
            link     = s.link     or "",
            active   = (s[".name"] == active),
        }
    end)

    luci.template.render("dpi_rip/servers", { servers = servers })
end

-- ================================================================
-- Log
-- ================================================================
function action_log()
    luci.template.render("dpi_rip/log", {})
end

-- ================================================================
-- AJAX: статус
-- ================================================================
function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()

    local pid     = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
    local enabled = uci:get("dpi-rip", "main", "enabled") or "0"
    local active  = uci:get("dpi-rip", "main", "active_server") or ""
    local sname   = ""
    if active ~= "" then
        sname = uci:get("dpi-rip", active, "name") or active
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        running      = (pid ~= ""),
        enabled      = (enabled == "1"),
        pid          = pid,
        server_name  = sname,
    })
end

-- ================================================================
-- AJAX: toggle
-- ================================================================
function action_toggle()
    local uci = require "luci.model.uci".cursor()
    local sys = require "luci.sys"

    local enabled = uci:get("dpi-rip", "main", "enabled") or "0"
    local new_val = (enabled == "1") and "0" or "1"
    uci:set("dpi-rip", "main", "enabled", new_val)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    if new_val == "1" then sys.exec("/etc/init.d/dpi-rip start &")
    else                   sys.exec("/etc/init.d/dpi-rip stop &")
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({ ok = true, enabled = (new_val == "1") })
end

-- ================================================================
-- AJAX: add_server
-- ================================================================
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
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    http.prepare_content("application/json")
    http.write_json({ ok = true, id = sid, name = name, protocol = proto })
end

-- ================================================================
-- AJAX: del_server
-- ================================================================
function action_del_server()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sid  = http.formvalue("id") or ""

    if sid == "" then
        http.prepare_content("application/json")
        http.write_json({ ok = false, error = "No id" })
        return
    end

    local active = uci:get("dpi-rip", "main", "active_server") or ""
    if active == sid then uci:set("dpi-rip", "main", "active_server", "") end
    uci:delete("dpi-rip", sid)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

-- ================================================================
-- AJAX: set_active
-- ================================================================
function action_set_active()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"
    local sid  = http.formvalue("id") or ""

    uci:set("dpi-rip", "main", "active_server", sid)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")
    sys.exec("/etc/init.d/dpi-rip restart &")

    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

-- ================================================================
-- AJAX: get_log
-- ================================================================
function action_get_log()
    local http    = require "luci.http"
    local sys     = require "luci.sys"
    local logtype = http.formvalue("type") or "error"
    local lines   = tonumber(http.formvalue("lines")) or 100
    local logfile = (logtype == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"

    local content = sys.exec(string.format("tail -n %d %s 2>/dev/null", lines, logfile))
    http.prepare_content("application/json")
    http.write_json({ ok = true, content = content })
end

-- ================================================================
-- AJAX: clear_log
-- ================================================================
function action_clear_log()
    local http    = require "luci.http"
    local sys     = require "luci.sys"
    local logtype = http.formvalue("type") or "error"
    local logfile = (logtype == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"
    sys.exec("> " .. logfile .. " 2>/dev/null")
    http.prepare_content("application/json")
    http.write_json({ ok = true })
end

-- ================================================================
-- Helpers
-- ================================================================
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
    return (name ~= "" and name or nil)
end
