include $(TOPDIR)/rules.mk

PKG_NAME:=dpi-rip-node
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=LL33ch <ll33ch.dev@gmail.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/dpi-rip-node
  SECTION:=net
  CATEGORY:=Network
  TITLE:=DPI-RIP Node — internet censorship monitoring agent
  DEPENDS:=+curl +jsonfilter
  URL:=https://github.com/LL33ch/dpi-rip
endef

define Package/dpi-rip-node/description
  Monitoring agent for OpenWRT routers. Connects to a dpi-rip-panel
  instance, fetches the list of targets to test, runs HTTP/DNS
  availability checks, and reports results back to the panel.
endef

define Package/dpi-rip-node/conffiles
/etc/config/dpi-rip-node
endef

define Build/Compile
endef

define Package/dpi-rip-node/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/dpi-rip-node $(1)/etc/config/dpi-rip-node

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/dpi-rip-node $(1)/etc/init.d/dpi-rip-node

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/30-dpi-rip-node $(1)/etc/hotplug.d/iface/30-dpi-rip-node

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/dpi-rip-node $(1)/usr/sbin/dpi-rip-node
endef

$(eval $(call BuildPackage,dpi-rip-node))
