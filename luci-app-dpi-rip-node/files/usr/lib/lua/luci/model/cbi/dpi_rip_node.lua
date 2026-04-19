local sys = require "luci.sys"
local http = require "luci.http"
local disp = require "luci.dispatcher"

-- ── Статус сервиса ────────────────────────────────────────────────────────────

local running = sys.call("pgrep -f 'dpi-rip-node daemon' >/dev/null 2>&1") == 0

local base_url = disp.build_url("admin/services/dpi-rip-node")
local msg = http.formvalue("msg")

-- ── Карта UCI ─────────────────────────────────────────────────────────────────

m = Map("dpi-rip-node",
	translate("DPI-RIP Node"),
	translate("Monitoring agent that tests internet accessibility " ..
	          "and reports results to the dpi-rip-panel."))

-- ── Секция: статус ────────────────────────────────────────────────────────────

s_info = m:section(NamedSection, "settings", "settings", translate("Status"))
s_info.anonymous = true
s_info.addremove  = false

-- Уведомление об action
if msg == "check" then
	local notice = s_info:option(DummyValue, "_msg_check")
	notice.rawhtml = true
	notice.value = "<div style='padding:6px 10px;background:#d4edda;border:1px solid #c3e6cb;" ..
	               "border-radius:4px;color:#155724;margin-bottom:8px'>" ..
	               "✓ " .. translate("Check cycle started in background") .. "</div>"
elseif msg == "register" then
	local notice = s_info:option(DummyValue, "_msg_reg")
	notice.rawhtml = true
	notice.value = "<div style='padding:6px 10px;background:#d4edda;border:1px solid #c3e6cb;" ..
	               "border-radius:4px;color:#155724;margin-bottom:8px'>" ..
	               "✓ " .. translate("Re-registration complete — reload page to see Node ID") .. "</div>"
end

-- Статус демона
local svc = s_info:option(DummyValue, "_svc_status", translate("Service"))
svc.rawhtml = true
svc.value = running
	and "<span style='color:#28a745;font-weight:bold'>● " .. translate("Running") .. "</span>"
	or  "<span style='color:#dc3545;font-weight:bold'>● " .. translate("Stopped") .. "</span>"

-- Node ID (read-only)
local nid = s_info:option(DummyValue, "node_id", translate("Node ID"))
nid.cfgvalue = function(self, section)
	local v = m.uci:get("dpi-rip-node", section, "node_id") or ""
	return v ~= "" and v or translate("(not registered yet)")
end

-- Кнопки действий
local actions = s_info:option(DummyValue, "_actions", translate("Actions"))
actions.rawhtml = true
actions.value = string.format(
	"<a href='%s/check' class='btn cbi-button cbi-button-apply' style='margin-right:6px'>" ..
	"▶ %s</a>" ..
	"<a href='%s/register' class='btn cbi-button cbi-button-neutral'>" ..
	"↺ %s</a>",
	base_url, translate("Run check now"),
	base_url, translate("Re-register")
)

-- ── Секция: подключение ───────────────────────────────────────────────────────

s = m:section(NamedSection, "settings", "settings", translate("Connection"))
s.anonymous = true
s.addremove  = false

local en = s:option(Flag, "enabled", translate("Enabled"))
en.rmempty = false
en.default = "1"

local url = s:option(Value, "panel_url", translate("Panel URL"),
	translate("URL of the panel instance, without trailing slash"))
url.placeholder = "https://panel.example.com"
url.rmempty = false

local key = s:option(Value, "api_key", translate("API Key"),
	translate("Issued by the panel when adding this node"))
key.password = true
key.rmempty  = false

-- ── Секция: параметры ─────────────────────────────────────────────────────────

s2 = m:section(NamedSection, "settings", "settings", translate("Parameters"))
s2.anonymous = true
s2.addremove  = false

local iv = s2:option(Value, "interval", translate("Check Interval"),
	translate("Seconds between check cycles"))
iv.datatype   = "uinteger"
iv.default    = "300"
iv.placeholder = "300"

local to = s2:option(Value, "timeout", translate("Request Timeout"),
	translate("Seconds to wait for each HTTP request"))
to.datatype   = "uinteger"
to.default    = "10"
to.placeholder = "10"

return m
