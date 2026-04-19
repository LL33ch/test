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
  Provides Settings page under Services → DPI-RIP Node.
endef

define Build/Compile
endef

define Package/luci-app-dpi-rip-node/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/dpi-rip-node
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/dpi-rip-node/settings.js \
		$(1)/www/luci-static/resources/view/dpi-rip-node/settings.js

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-dpi-rip-node.json \
		$(1)/usr/share/luci/menu.d/luci-app-dpi-rip-node.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json \
		$(1)/usr/share/rpcd/acl.d/luci-app-dpi-rip-node.json

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/dpi-rip-node \
		$(1)/usr/libexec/rpcd/dpi-rip-node
endef

$(eval $(call BuildPackage,luci-app-dpi-rip-node))
