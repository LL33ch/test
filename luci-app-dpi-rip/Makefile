include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dpi-rip
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

LUCI_TITLE:=DPI-RIP — Xray VPN for OpenWRT
LUCI_DEPENDS:=+xray-core +ip +iptables +iptables-mod-tproxy +kmod-ipt-tproxy +resolveip

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,luci-app-dpi-rip))
