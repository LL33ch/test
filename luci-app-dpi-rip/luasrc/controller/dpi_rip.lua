-- DPI-RIP LuCI Controller
-- Compatible with all OpenWRT versions: uses only call() + template(), no luci.cbi
-- Supports multiple subscriptions

module("luci.controller.dpi_rip", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/dpi-rip") then return end

    local root = entry(
        {"admin", "services", "dpi-rip"},
        alias("admin", "services", "dpi-rip", "overview"),
        _("DPI-RIP"), 60
    )
    root.dependent  = true
    root.acl_depends = { "luci-app-dpi-rip" }

    entry({"admin", "services", "dpi-rip", "overview"},
        call("action_overview"), _("Overview"), 10)

    entry({"admin", "services", "dpi-rip", "subs"},
        call("action_subs"), _("Subscriptions"), 20)

    entry({"admin", "services", "dpi-rip", "log"},
        call("action_log"), _("Log"), 30)

    -- AJAX endpoints
    entry({"admin", "services", "dpi-rip", "status"},
        call("action_status")).leaf = true

    entry({"admin", "services", "dpi-rip", "toggle"},
        call("action_toggle")).leaf = true

    entry({"admin", "services", "dpi-rip", "add_sub"},
        call("action_add_sub")).leaf = true

    entry({"admin", "services", "dpi-rip", "del_sub"},
        call("action_del_sub")).leaf = true

    entry({"admin", "services", "dpi-rip", "fetch_sub"},
        call("action_fetch_sub")).leaf = true

    entry({"admin", "services", "dpi-rip", "get_log"},
        call("action_get_log")).leaf = true

    entry({"admin", "services", "dpi-rip", "clear_log"},
        call("action_clear_log")).leaf = true
end

-- ================================================================
-- Overview page: status + server selection
-- ================================================================
function action_overview()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    if http.getenv("REQUEST_METHOD") == "POST" then
        -- Save active server + settings, then restart
        local combined   = http.formvalue("active") or ""
        local proxy_mode = http.formvalue("proxy_mode") or "tproxy"
        local enabled    = http.formvalue("enabled") or "0"

        -- Value format: "sub_id|remarks" (see overview.htm <option> values)
        local sub_id = combined:match("^([^|]*)|") or ""
        local remarks = combined:match("^[^|]*|(.+)") or ""

        uci:set("dpi-rip", "main", "active_sub",     sub_id)
        uci:set("dpi-rip", "main", "active_remarks", remarks)
        uci:set("dpi-rip", "main", "proxy_mode",     proxy_mode)
        uci:set("dpi-rip", "main", "enabled",        enabled)
        uci:save("dpi-rip")
        uci:commit("dpi-rip")

        if enabled == "1" then
            sys.exec("/etc/init.d/dpi-rip restart &")
        else
            sys.exec("/etc/init.d/dpi-rip stop &")
        end

        http.redirect(luci.dispatcher.build_url("admin", "services", "dpi-rip", "overview"))
        return
    end

    local cfg = {
        active_sub     = uci:get("dpi-rip", "main", "active_sub")     or "",
        active_remarks = uci:get("dpi-rip", "main", "active_remarks") or "",
        proxy_mode     = uci:get("dpi-rip", "main", "proxy_mode")     or "tproxy",
        enabled        = uci:get("dpi-rip", "main", "enabled")        or "0",
    }

    local pid = (sys.exec("pgrep -f 'xray run' 2>/dev/null | head -1") or ""):gsub("%s+", "")
    cfg.running = (pid ~= "")
    cfg.pid     = pid
    cfg.subs    = load_all_subs()

    local token = http.formtoken and http.formtoken() or ""
    luci.template.render("dpi_rip/overview", { cfg = cfg, token = token })
end

-- ================================================================
-- Subscriptions management page
-- ================================================================
function action_subs()
    local http  = require "luci.http"
    local token = http.formtoken and http.formtoken() or ""
    luci.template.render("dpi_rip/subs", { subs = load_all_subs(), token = token })
end

-- ================================================================
-- Log viewer page
-- ================================================================
function action_log()
    local http  = require "luci.http"
    local token = http.formtoken and http.formtoken() or ""
    luci.template.render("dpi_rip/log", { token = token })
end

-- ================================================================
-- AJAX: status
-- ================================================================
function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()

    local pid     = (sys.exec("pgrep -f 'xray run' 2>/dev/null | head -1") or ""):gsub("%s+", "")
    local enabled = uci:get("dpi-rip", "main", "enabled")        or "0"
    local sub_id  = uci:get("dpi-rip", "main", "active_sub")     or ""
    local remarks = uci:get("dpi-rip", "main", "active_remarks") or ""

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        running        = (pid ~= ""),
        enabled        = (enabled == "1"),
        pid            = pid,
        active_sub     = sub_id,
        active_remarks = remarks,
    })
end

-- ================================================================
-- AJAX: toggle enable/disable
-- ================================================================
function action_toggle()
    local uci = require "luci.model.uci".cursor()
    local sys = require "luci.sys"

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

    luci.http.prepare_content("application/json")
    luci.http.write_json({ ok = true, enabled = (new_val == "1") })
end

-- ================================================================
-- AJAX: add subscription
-- POST params: url
-- Returns: {ok, sub_id, log, count, title, info}
-- ================================================================
function action_add_sub()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local url = trim(http.formvalue("url") or "")
    if url == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({ ok = false, error = "URL is required" })
        return
    end

    -- Generate unique section name (timestamp-based)
    local sub_id = "s" .. tostring(os.time())

    -- Create UCI section
    uci:set("dpi-rip", sub_id, "subscription")
    uci:set("dpi-rip", sub_id, "url",   url)
    uci:set("dpi-rip", sub_id, "title", "")
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    -- Write URL to temp file BEFORE exec — bypasses any UCI commit timing issue
    write_url_hint(sub_id, url)

    local log     = sys.exec("/usr/bin/dpi-rip-fetch.sh " .. sub_id .. " 2>&1") or ""
    local servers = load_servers(sub_id)
    local info    = load_sub_info(sub_id)

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        ok     = (#servers > 0),
        sub_id = sub_id,
        log    = log,
        count  = #servers,
        title  = (info and info.title ~= "" and info.title) or sub_id,
        info   = info,
    })
end

-- ================================================================
-- AJAX: delete subscription
-- POST params: sub_id
-- ================================================================
function action_del_sub()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local sub_id = trim(http.formvalue("sub_id") or "")
    if not validate_sub_id(sub_id) then
        luci.http.prepare_content("application/json")
        luci.http.write_json({ ok = false, error = "invalid sub_id" })
        return
    end

    -- If this was the active subscription, clear it
    local active = uci:get("dpi-rip", "main", "active_sub") or ""
    if active == sub_id then
        uci:set("dpi-rip", "main", "active_sub",     "")
        uci:set("dpi-rip", "main", "active_remarks", "")
        uci:set("dpi-rip", "main", "enabled",        "0")
        sys.exec("/etc/init.d/dpi-rip stop &")
    end

    uci:delete("dpi-rip", sub_id)
    uci:save("dpi-rip")
    uci:commit("dpi-rip")

    -- Remove data files
    sys.exec("rm -f '/etc/dpi-rip/sub_" .. sub_id .. ".json' "
           .. "'/etc/dpi-rip/sub_" .. sub_id .. "_info.json' 2>/dev/null")

    luci.http.prepare_content("application/json")
    luci.http.write_json({ ok = true })
end

-- ================================================================
-- AJAX: refresh (re-fetch) a subscription
-- POST params: sub_id, url (optional — to update URL)
-- ================================================================
function action_fetch_sub()
    local http = require "luci.http"
    local uci  = require "luci.model.uci".cursor()
    local sys  = require "luci.sys"

    local sub_id = trim(http.formvalue("sub_id") or "")
    local url    = trim(http.formvalue("url")    or "")

    if not validate_sub_id(sub_id) then
        luci.http.prepare_content("application/json")
        luci.http.write_json({ ok = false, error = "invalid sub_id" })
        return
    end

    -- Update URL in UCI if provided
    if url ~= "" then
        uci:set("dpi-rip", sub_id, "url", url)
        uci:save("dpi-rip")
        uci:commit("dpi-rip")
    else
        url = uci:get("dpi-rip", sub_id, "url") or ""
    end

    if url == "" then
        luci.http.prepare_content("application/json")
        luci.http.write_json({ ok = false, error = "no URL configured" })
        return
    end

    -- Write URL hint to temp file
    write_url_hint(sub_id, url)

    local log     = sys.exec("/usr/bin/dpi-rip-fetch.sh " .. sub_id .. " 2>&1") or ""
    local servers = load_servers(sub_id)
    local info    = load_sub_info(sub_id)

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        ok      = (#servers > 0),
        log     = log,
        count   = #servers,
        title   = (info and info.title ~= "" and info.title) or sub_id,
        servers = servers,
        info    = info,
    })
end

-- ================================================================
-- AJAX: get log
-- GET params: type (error|access), lines
-- ================================================================
function action_get_log()
    local http    = require "luci.http"
    local sys     = require "luci.sys"
    local logtype = http.formvalue("type") or "error"
    local lines   = math.min(tonumber(http.formvalue("lines") or 100) or 100, 1000)
    local logfile = (logtype == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"

    local content = sys.exec(string.format("tail -n %d %s 2>/dev/null", lines, logfile)) or ""
    luci.http.prepare_content("application/json")
    luci.http.write_json({ ok = true, content = content })
end

-- ================================================================
-- AJAX: clear log
-- POST params: type (error|access)
-- ================================================================
function action_clear_log()
    local http    = require "luci.http"
    local sys     = require "luci.sys"
    local logtype = http.formvalue("type") or "error"
    local logfile = (logtype == "access")
        and "/var/log/dpi-rip-access.log"
        or  "/var/log/dpi-rip-error.log"
    sys.exec("> " .. logfile .. " 2>/dev/null")
    luci.http.prepare_content("application/json")
    luci.http.write_json({ ok = true })
end

-- ================================================================
-- Helpers
-- ================================================================

-- Load all subscriptions with their server lists and meta info
function load_all_subs()
    local uci  = require "luci.model.uci".cursor()
    local subs = {}
    uci:foreach("dpi-rip", "subscription", function(s)
        local id      = s[".name"]
        local info    = load_sub_info(id)
        local servers = load_servers(id)
        local title   = (info and info.title and info.title ~= "" and info.title)
                     or (s.title and s.title ~= "" and s.title)
                     or id
        subs[#subs + 1] = {
            id      = id,
            url     = s.url or "",
            title   = title,
            servers = servers,
            count   = #servers,
            info    = info,
        }
    end)
    return subs
end

-- Load server list for one subscription (returns [{remarks, protocol}])
function load_servers(sub_id)
    if not validate_sub_id(sub_id) then return {} end
    local sys  = require "luci.sys"
    local file = "/etc/dpi-rip/sub_" .. sub_id .. ".json"
    local out  = sys.exec("/usr/bin/dpi-rip-list.sh " .. file .. " 2>/dev/null") or ""
    local servers = {}
    for line in out:gmatch("[^\n]+") do
        local remarks, protocol = line:match("^(.*)\t(.*)$")
        if remarks and remarks ~= "" then
            servers[#servers + 1] = { remarks = remarks, protocol = protocol or "?" }
        end
    end
    return servers
end

-- Load meta info for one subscription from JSON file
function load_sub_info(sub_id)
    if not validate_sub_id(sub_id) then return nil end
    local sys = require "luci.sys"
    local raw = sys.exec("cat '/etc/dpi-rip/sub_" .. sub_id .. "_info.json' 2>/dev/null") or ""
    if raw == "" then return nil end

    return {
        title      = raw:match('"title"%s*:%s*"([^"]*)"')      or "",
        used_fmt   = raw:match('"used_fmt"%s*:%s*"([^"]*)"')   or "",
        total_fmt  = raw:match('"total_fmt"%s*:%s*"([^"]*)"')  or "",
        expire_str = raw:match('"expire_str"%s*:%s*"([^"]*)"') or "",
        used_pct   = tonumber(raw:match('"used_pct"%s*:%s*([%d%.]+)')) or 0,
        count      = tonumber(raw:match('"count"%s*:%s*([%d]+)'))      or 0,
    }
end

-- Write URL to temp file so fetch.sh reads it immediately (no UCI timing issue)
function write_url_hint(sub_id, url)
    local f = io.open("/tmp/dpi-rip-url-" .. sub_id, "w")
    if f then
        f:write(url)
        f:close()
    end
end

-- Validate that sub_id is safe to use in shell commands
function validate_sub_id(s)
    return s and s ~= "" and not s:match("[^%w_]")
end

-- Trim leading/trailing whitespace
function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end
