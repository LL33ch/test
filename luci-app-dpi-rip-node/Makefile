include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dpi-rip-node
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=LL33ch <ll33ch.dev@gmail.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-dpi-rip-node
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for DPI-RIP Node
  DEPENDS:=+luci-base +dpi-rip-node
  PKGARCH:=all
endef

define Package/luci-app-dpi-rip-node/description
  LuCI web interface for the dpi-rip-node monitoring agent.
  Provides settings page under Services → DPI-RIP Node.
endef

define Build/Compile
endef

define Package/luci-app-dpi-rip-node/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/dpi_rip_node.lua \
		$(1)/usr/lib/lua/luci/controller/dpi_rip_node.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/dpi_rip_node.lua \
		$(1)/usr/lib/lua/luci/model/cbi/dpi_rip_node.lua
endef

$(eval $(call BuildPackage,luci-app-dpi-rip-node))
