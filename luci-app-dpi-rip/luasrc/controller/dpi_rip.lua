-- DPI-RIP LuCI Controller (subscription-based)
-- Работает на любой версии OpenWRT: только call() + template(), без luci.cbi

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

    entry({"admin", "services", "dpi-rip", "log"},
        call("action_log"), _("Log"), 20)

    -- AJAX
    entry({"admin", "services", "dpi-rip", "status"},
        call("action_status")).leaf = true

    entry({"admin", "services", "dpi-rip", "toggle"},
        call("action_toggle")).leaf = true

    entry({"admin", "services", "dpi-rip", "fetch_sub"},
        call("action_fetch_sub")).leaf = true

    entry({"admin", "services", "dpi-rip", "get_log"},
        call("action_get_log")).leaf = true

    entry({"admin", "services", "dpi-rip", "clear_log"},
        call("action_clear_log")).leaf = true
end

-- ================================================================
-- Overview
-- ================================================================
function action_overview()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    if http.getenv("REQUEST_METHOD") == "POST" then
        local action = http.formvalue("action") or "save"

        if action == "fetch" then
            -- Сохраняем URL и запускаем fetch
            local sub_url = (http.formvalue("sub_url") or ""):gsub("%s+", "")
            uci:set("dpi-rip", "main", "sub_url", sub_url)
            uci:save("dpi-rip")
            uci:commit("dpi-rip")
            sys.exec("/usr/bin/dpi-rip-fetch.sh > /tmp/dpi-rip-fetch.log 2>&1")

        elseif action == "save" then
            local remarks    = http.formvalue("active_remarks") or ""
            local proxy_mode = http.formvalue("proxy_mode") or "tproxy"
            local enabled    = http.formvalue("enabled") or "0"

            uci:set("dpi-rip", "main", "active_remarks", remarks)
            uci:set("dpi-rip", "main", "proxy_mode",     proxy_mode)
            uci:set("dpi-rip", "main", "enabled",        enabled)
            uci:save("dpi-rip")
            uci:commit("dpi-rip")
            sys.exec("/etc/init.d/dpi-rip restart &")
        end

        http.redirect(luci.dispatcher.build_url("admin", "services", "dpi-rip", "overview"))
        return
    end

    -- Данные для шаблона
    local cfg = {
        sub_url        = uci:get("dpi-rip", "main", "sub_url")        or "",
        active_remarks = uci:get("dpi-rip", "main", "active_remarks") or "",
        proxy_mode     = uci:get("dpi-rip", "main", "proxy_mode")     or "tproxy",
        enabled        = uci:get("dpi-rip", "main", "enabled")        or "0",
    }

    local pid = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
    cfg.running = (pid ~= "")
    cfg.pid     = pid

    -- Читаем список серверов и мета-информацию подписки
    cfg.servers  = load_servers()
    cfg.sub_info = load_sub_info()
    cfg.fetch_log = sys.exec("cat /tmp/dpi-rip-fetch.log 2>/dev/null") or ""

    local token = http.formtoken and http.formtoken() or ""
    luci.template.render("dpi_rip/overview", { cfg = cfg, token = token })
end

-- ================================================================
-- Log
-- ================================================================
function action_log()
    local http  = require "luci.http"
    local token = http.formtoken and http.formtoken() or ""
    luci.template.render("dpi_rip/log", { token = token })
end

-- ================================================================
-- AJAX: статус
-- ================================================================
function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()

    local pid     = sys.exec("pgrep -f 'xray run' | head -1"):gsub("%s+", "")
    local enabled = uci:get("dpi-rip", "main", "enabled") or "0"
    local remarks = uci:get("dpi-rip", "main", "active_remarks") or ""

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        running        = (pid ~= ""),
        enabled        = (enabled == "1"),
        pid            = pid,
        active_remarks = remarks,
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
-- AJAX: fetch_sub (обновить подписку без перезагрузки страницы)
-- ================================================================
function action_fetch_sub()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local sub_url = (http.formvalue("sub_url") or ""):gsub("%s+", "")
    if sub_url ~= "" then
        uci:set("dpi-rip", "main", "sub_url", sub_url)
        uci:save("dpi-rip")
        uci:commit("dpi-rip")
    end

    local ret = sys.exec("/usr/bin/dpi-rip-fetch.sh 2>&1")
    local servers = load_servers()

    http.prepare_content("application/json")
    http.write_json({
        ok      = (servers ~= nil and #servers > 0),
        log     = ret,
        servers = servers or {},
        count   = servers and #servers or 0,
    })
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
-- Helper: читаем servers.json через python3
-- ================================================================
function load_servers()
    local sys = require "luci.sys"
    local json_str = sys.exec(
        "python3 -c \""..
        "import json,sys;"..
        "d=json.load(open('/etc/dpi-rip/servers.json'));"..
        "print(json.dumps([{'remarks':s.get('remarks',''),'protocol':s.get('outbounds',[{}])[0].get('protocol','?')} for s in d]))"..
        "\" 2>/dev/null"
    )
    if not json_str or json_str == "" then return {} end

    -- Простой парсинг JSON массива через lua (без зависимостей)
    local servers = {}
    for proto, remarks in json_str:gmatch('"protocol"%s*:%s*"([^"]*)"[^}]*"remarks"%s*:%s*"([^"]*)"') do
        servers[#servers + 1] = { protocol = proto, remarks = remarks }
    end
    -- Пробуем обратный порядок полей
    if #servers == 0 then
        for remarks, proto in json_str:gmatch('"remarks"%s*:%s*"([^"]*)"[^}]*"protocol"%s*:%s*"([^"]*)"') do
            servers[#servers + 1] = { protocol = proto, remarks = remarks }
        end
    end
    return servers
end

-- ================================================================
-- Helper: читаем sub-info.json
-- ================================================================
function load_sub_info()
    local sys = require "luci.sys"
    local raw = sys.exec("cat /etc/dpi-rip/sub-info.json 2>/dev/null")
    if not raw or raw == "" then return nil end

    local info = {}
    info.title      = raw:match('"title"%s*:%s*"([^"]*)"')      or ""
    info.used_fmt   = raw:match('"used_fmt"%s*:%s*"([^"]*)"')   or ""
    info.total_fmt  = raw:match('"total_fmt"%s*:%s*"([^"]*)"')  or ""
    info.expire_str = raw:match('"expire_str"%s*:%s*"([^"]*)"') or ""
    info.used_pct   = tonumber(raw:match('"used_pct"%s*:%s*([%d%.]+)')) or 0
    return info
end
