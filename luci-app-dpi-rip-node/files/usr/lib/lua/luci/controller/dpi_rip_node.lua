module("luci.controller.dpi_rip_node", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/dpi-rip-node") then
		return
	end

	local page = entry(
		{"admin", "services", "dpi-rip-node"},
		cbi("dpi_rip_node"),
		_("DPI-RIP Node"),
		10
	)
	page.dependent = true

	-- Действие: запустить проверку вручную
	entry({"admin", "services", "dpi-rip-node", "check"},
		call("action_check"), nil)

	-- Действие: перерегистрировать ноду
	entry({"admin", "services", "dpi-rip-node", "register"},
		call("action_register"), nil)
end

function action_check()
	luci.sys.call("/usr/sbin/dpi-rip-node check >/dev/null 2>&1 &")
	luci.http.redirect(
		luci.dispatcher.build_url("admin/services/dpi-rip-node") .. "?msg=check"
	)
end

function action_register()
	luci.sys.call("/usr/sbin/dpi-rip-node register >/dev/null 2>&1")
	luci.http.redirect(
		luci.dispatcher.build_url("admin/services/dpi-rip-node") .. "?msg=register"
	)
end
