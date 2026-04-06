#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 检查目录是否存在
		if [ ! -d "../feeds/luci/" ] && [ ! -d "../feeds/packages/" ]; then
			continue
		fi
		
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
			done <<< "$FOUND_DIRS"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		# 遍历每个匹配的目录并复制
		for dir in $(find ./$REPO_NAME/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -print); do
			dir_name=$(basename "$dir")
			# 跳过克隆的根目录本身
			[[ "$dir_name" == "$REPO_NAME" ]] && continue
			# 精确匹配：目录名必须完全等于 PKG_NAME
			if [[ "$dir_name" == "$PKG_NAME" ]]; then
				# 如果目标目录已存在，先删除
				[ -d "./$dir_name" ] && rm -rf "./$dir_name"
				# 复制目录
				cp -rf "$dir" ./
			fi
		done
		
		# 如果是 packages 类型的仓库（如 passwall-packages），复制所有子包
		if [[ "$PKG_NAME" == *"packages"* ]] || [[ "$PKG_NAME" == *"package"* ]]; then
			for dir in ./$REPO_NAME/*/; do
				if [ -d "$dir" ]; then
					dir_name=$(basename "$dir")
					# 跳过已处理的目录
					[[ "$dir_name" == "$PKG_NAME" ]] && continue
					# 如果目标目录已存在，先删除
					[ -d "./$dir_name" ] && rm -rf "./$dir_name"
					# 复制目录
					cp -rf "$dir" ./
				fi
			done
		fi
		
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

# ============================================
# 软件包调用
# ============================================

# 主题
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"

# 科学上网插件
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main" "pkg"

# DNS 相关
UPDATE_PACKAGE "smartdns" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-smartdns" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-adguardhome" "wzdddyy/luci-app-adguardhome" "master"

# 工具插件
UPDATE_PACKAGE "luci-app-quickstart" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-istorex" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-store" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-lib-taskd" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-lucky" "kenzok8/openwrt-packages" "master" "pkg"
UPDATE_PACKAGE "luci-app-oaf" "destan19/OpenAppFilter" "master"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "dockerman" "wzdddyy/luci-app-dockerman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"

# 版本自动更新
#UPDATE_VERSION "sing-box"
