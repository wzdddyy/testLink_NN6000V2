#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置PassWall2数据
if [ -d *"passwall2"* ] || [ -d *"luci-app-passwall2"* ]; then
	echo " "

	PW_PATH=$(find . -maxdepth 3 -type d -name "luci-app-passwall2" -o -name "passwall2" | head -1)
	
	if [ -n "$PW_PATH" ]; then
		PW_RULES_PATH="$PW_PATH/root/usr/share/passwall/rules"
		
		if [ -d "$PW_RULES_PATH" ]; then
			# 预置 GFW 列表和大陆 IP 列表
			git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./pw_rules/
			cd ./pw_rules/
			
			# 生成 gfwlist.txt
			awk '/^DOMAIN-SUFFIX,/{print $2}' gfw.txt > "$PW_RULES_PATH/gfwlist.txt" 2>/dev/null || true
			
			# 生成 china_ip.txt
			awk -F, '/^IP-CIDR,/{print $2}' cncidr.txt > "$PW_RULES_PATH/china_ip.txt" 2>/dev/null || true
			
			cd .. && rm -rf ./pw_rules/
			
			echo "passwall2 rules has been pre-configured!"
		fi
	fi
fi

#移除uhttpd依赖 (默认使用nginx)
LUCI_MAKEFILE="$(find ./feeds/luci/collections/ -type f -name "Makefile" 2>/dev/null | head -1)"

if [ -n "$LUCI_MAKEFILE" ]; then
	sed -i '/luci-light/d' $LUCI_MAKEFILE
	echo "uhttpd dependency removed, using nginx as default web server!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#28a745'/; s/dark_primary '.*'/dark_primary '#4A6B5D'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi



#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复缺失的Python依赖
echo " "
echo "Checking Python dependencies..."

# python3-pkg-resources
PYTHON_PKG_RESOURCES=$(find ../feeds/packages/ -maxdepth 4 -type f -wholename "*/python3-setuptools/Makefile" 2>/dev/null | head -1)
if [ -n "$PYTHON_PKG_RESOURCES" ]; then
	echo "✓ python3-setuptools found (provides python3-pkg-resources)"
else
	echo "⚠ python3-setuptools not found, may cause dependency warnings"
fi

#检查并添加缺失的LuCI依赖
echo " "
echo "Adding LuCI dependencies..."

# 添加 luci-app-store
if [ ! -d "../../feeds/luci/luci-app-store" ] && [ ! -d "./luci-app-store" ]; then
	echo "Cloning luci-app-store..."
	git clone --depth=1 --single-branch --branch main https://github.com/linkease/istore-packages.git ./istore-packages 2>/dev/null || true
	if [ -d "./istore-packages/luci-app-store" ]; then
		mkdir -p ../../feeds/luci/
		mv ./istore-packages/luci-app-store ../../feeds/luci/
		rm -rf ./istore-packages
		echo "✓ luci-app-store added to feeds/luci/"
	else
		rm -rf ./istore-packages
	fi
fi

# 添加 luci-lib-taskd
if [ ! -d "../../feeds/luci/luci-lib-taskd" ] && [ ! -d "./luci-lib-taskd" ]; then
	echo "Cloning luci-lib-taskd..."
	git clone --depth=1 --single-branch --branch main https://github.com/istorehub/luci-lib-taskd.git ./luci-lib-taskd 2>/dev/null || true
	if [ -d "./luci-lib-taskd" ]; then
		mkdir -p ../../feeds/luci/
		mv ./luci-lib-taskd ../../feeds/luci/
		echo "✓ luci-lib-taskd added to feeds/luci/"
	fi
fi

#检查并添加5G模块依赖
echo " "
echo "Adding 5G module dependencies..."

# 添加 quectel-CM-5G
if [ ! -d "../../feeds/packages/quectel-CM-5G" ] && [ ! -d "./quectel-CM-5G" ]; then
	echo "Cloning quectel-CM-5G..."
	git clone --depth=1 --single-branch --branch master https://github.com/niceboygithub/quectel-CM-5G.git ./quectel-CM-5G 2>/dev/null || true
	if [ -d "./quectel-CM-5G" ]; then
		mkdir -p ../../feeds/packages/
		mv ./quectel-CM-5G ../../feeds/packages/
		echo "✓ quectel-CM-5G added to feeds/packages/"
	fi
fi

# kmod-mhi-wwan
echo "✓ kmod-mhi-wwan (kernel module, should be included in qualcommax target)"

echo " "
echo "Dependency check complete!"

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

#修复luci-app-netspeedtest相关问题
if [ -d *"luci-app-netspeedtest"* ]; then
	echo " "

	cd ./luci-app-netspeedtest/

	sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults
	sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile

	cd $PKG_PATH && echo "netspeedtest has been fixed!"
fi

#配置 WiFi 参数
WIFI_PATCH="$GITHUB_WORKSPACE/Patches/992_set-wifi-uci.sh"
WIFI_TARGET="$GITHUB_WORKSPACE/wrt/package/network/config/wifi-scripts/files/etc/uci-defaults/992_set-wifi-uci.sh"
if [ -f "$WIFI_PATCH" ]; then
	echo " "
	
	mkdir -p $(dirname $WIFI_TARGET)
	cp -f $WIFI_PATCH $WIFI_TARGET
	
	# 替换环境变量
	sed -i "s/\$WIFI_SSID/$WIFI_SSID/g" $WIFI_TARGET
	sed -i "s/\$WIFI_PASSWORD/$WIFI_PASSWORD/g" $WIFI_TARGET
	sed -i "s/\$WIFI_DISABLED/$WIFI_DISABLED/g" $WIFI_TARGET
	
	chmod +x $WIFI_TARGET
	
	echo "WiFi configuration has been applied!"
fi

#配置系统监控脚本
for patch in cpuusage tempinfo; do
	PATCH_FILE="$GITHUB_WORKSPACE/Patches/$patch"
	TARGET_FILE="$GITHUB_WORKSPACE/wrt/package/emortal/default-settings/files/$patch"
	
	if [ -f "$PATCH_FILE" ]; then
		echo " "
		
		mkdir -p $(dirname $TARGET_FILE)
		cp -f $PATCH_FILE $TARGET_FILE
		chmod +x $TARGET_FILE
		
		echo "$patch has been configured!"
	fi
done

#配置系统自定义设置
CUSTOM_SETTINGS="$GITHUB_WORKSPACE/Patches/991_custom_settings"
CUSTOM_TARGET="$GITHUB_WORKSPACE/wrt/package/emortal/default-settings/files/991_custom_settings"

if [ -f "$CUSTOM_SETTINGS" ]; then
	echo " "
	
	mkdir -p $(dirname $CUSTOM_TARGET)
	cp -f $CUSTOM_SETTINGS $CUSTOM_TARGET
	chmod +x $CUSTOM_TARGET
	
	echo "Custom settings has been configured!"
fi

#配置 PPPoE 拨号
PPPOE_PATCH="$GITHUB_WORKSPACE/Patches/993_set_pppoe.sh"
PPPOE_TARGET="$GITHUB_WORKSPACE/wrt/package/network/config/files/etc/uci-defaults/993_set_pppoe.sh"

if [ -f "$PPPOE_PATCH" ]; then
	echo " "
	
	mkdir -p $(dirname $PPPOE_TARGET)
	cp -f $PPPOE_PATCH $PPPOE_TARGET
	
	# 替换环境变量
	if [ -n "$PPPOE_USERNAME" ] && [ -n "$PPPOE_PASSWORD" ]; then
		sed -i "s/\${WRT_PPPOE_USERNAME:--}/$PPPOE_USERNAME/g" $PPPOE_TARGET
		sed -i "s/\${WRT_PPPOE_PASSWORD:--}/$PPPOE_PASSWORD/g" $PPPOE_TARGET
	fi
	
	chmod +x $PPPOE_TARGET
	
	echo "PPPoE configuration has been added!"
fi

#配置 NSS 诊断脚本
NSS_DIAG="$GITHUB_WORKSPACE/Patches/nss_diag.sh"
NSS_DIAG_TARGET="$GITHUB_WORKSPACE/wrt/package/emortal/default-settings/files/nss_diag.sh"

if [ -f "$NSS_DIAG" ]; then
	echo " "
	
	mkdir -p $(dirname $NSS_DIAG_TARGET)
	cp -f $NSS_DIAG $NSS_DIAG_TARGET
	chmod +x $NSS_DIAG_TARGET
	
	echo "NSS diagnostic script has been configured!"
fi