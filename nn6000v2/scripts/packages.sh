#!/usr/bin/env bash

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        \rm -rf ./feeds/packages/lang/golang
        if ! git clone --depth 1 -b $GOLANG_BRANCH $GOLANG_REPO ./feeds/packages/lang/golang; then
            echo "错误：克隆 golang 仓库 $GOLANG_REPO 失败" >&2
            exit 1
        fi
        echo "✓ golang 软件包更新完成"
    fi
}

install_openwrt_packages() {
    ./scripts/feeds install -p openwrt_packages -f \
        xray-core sing-box trojan-plus naiveproxy shadowsocks-libev v2ray-plugin geoview \
        microsocks tcping chinadns-ng dns2socks resolveip \
        taskd luci-lib-xterm luci-lib-taskd \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex \
        smartdns luci-app-smartdns luci-theme-argon luci-app-argon-config \
        luci-lib-docker luci-app-lucky luci-app-adguardhome luci-app-easytier \
        luci-app-oaf oaf open-app-filter \
        luci-app-diskman luci-app-dockerman luci-app-quickfile luci-app-passwall
}

install_passwall() {
    local PASSWALL_LUCI_DIR="$BUILD_DIR/feeds/openwrt_packages/luci-app-passwall"
    local PASSWALL_PACKAGES_DIR="$BUILD_DIR/feeds/openwrt_packages/passwall-packages"
    local TEMP_DIR="$BUILD_DIR/feeds/openwrt_packages/openwrt-passwall-temp"
    
    # 克隆 openwrt-passwall 仓库
    rm -rf "$TEMP_DIR"
    if ! git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall.git "$TEMP_DIR"; then
        echo "错误：克隆 openwrt-passwall 仓库失败" >&2
        exit 1
    fi
    
    rm -rf "$PASSWALL_LUCI_DIR" 2>/dev/null || true
    mv "$TEMP_DIR/luci-app-passwall" "$PASSWALL_LUCI_DIR"
    rm -rf "$TEMP_DIR"
    echo "✓ luci-app-passwall 克隆完成"
    
    rm -rf "$PASSWALL_PACKAGES_DIR" 2>/dev/null || true
    local PASSWALL_PKGS_TEMP="$BUILD_DIR/feeds/openwrt_packages/passwall-packages-temp"
    rm -rf "$PASSWALL_PKGS_TEMP"
    if ! git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git "$PASSWALL_PKGS_TEMP"; then
        echo "错误：克隆 openwrt-passwall-packages 仓库失败" >&2
        exit 1
    fi
    
    for pkg in "$PASSWALL_PKGS_TEMP"/*; do
        if [ -d "$pkg" ]; then
            local pkg_name=$(basename "$pkg")
            mv "$pkg" "$BUILD_DIR/feeds/openwrt_packages/$pkg_name"
        fi
    done
    rm -rf "$PASSWALL_PKGS_TEMP"
    echo "✓ passwall-packages 克隆并移动完成"
    
    echo "✓ Passwall 安装完成"
}

install_fullconenat() {
    # 安装 fullconenat
    ./scripts/feeds install -p packages -f kmod-nft-fullcone
}

install_lucky() {
    local LUCKY_REPO="https://github.com/gdy666/luci-app-lucky.git"
    local LUCKY_DIR="$BUILD_DIR/feeds/openwrt_packages/lucky"
    local LUCI_APP_LUCKY_DIR="$BUILD_DIR/feeds/openwrt_packages/luci-app-lucky"

    # 克隆 lucky core
    rm -rf "$LUCKY_DIR" 2>/dev/null || true
    if ! git clone --depth=1 --filter=blob:none --no-checkout "$LUCKY_REPO" "$LUCKY_DIR"; then
        echo "错误：从 $LUCKY_REPO 克隆 lucky 仓库失败" >&2
        exit 1
    fi
    
    pushd "$LUCKY_DIR" >/dev/null
    git sparse-checkout init --cone
    git sparse-checkout set lucky || {
        echo "错误：稀疏检出 lucky 失败" >&2
        popd >/dev/null
        rm -rf "$LUCKY_DIR"
        exit 1
    }
    git checkout --quiet
    popd >/dev/null
    
    # 克隆 luci-app-lucky
    rm -rf "$LUCI_APP_LUCKY_DIR" 2>/dev/null || true
    if ! git clone --depth=1 --filter=blob:none --no-checkout "$LUCKY_REPO" "$LUCI_APP_LUCKY_DIR"; then
        echo "错误：从 $LUCKY_REPO 克隆 luci-app-lucky 仓库失败" >&2
        rm -rf "$LUCKY_DIR"
        exit 1
    fi
    
    pushd "$LUCI_APP_LUCKY_DIR" >/dev/null
    git sparse-checkout init --cone
    git sparse-checkout set luci-app-lucky || {
        echo "错误：稀疏检出 luci-app-lucky 失败" >&2
        popd >/dev/null
        rm -rf "$LUCKY_DIR"
        rm -rf "$LUCI_APP_LUCKY_DIR"
        exit 1
    }
    git checkout --quiet
    popd >/dev/null
    
    # 默认禁用 lucky 服务
    local lucky_conf="$LUCKY_DIR/lucky/files/luckyuci"
    if [ -f "$lucky_conf" ]; then
        sed -i "s/option enabled '1'/option enabled '0'/g" "$lucky_conf"
        sed -i "s/option logger '1'/option logger '0'/g" "$lucky_conf"
    fi
    
    # 处理补丁
    local version
    version=$(find "$BASE_PATH/patches" -name "lucky_*.tar.gz" -printf "%f\n" | head -n 1 | sed -n 's/^lucky_\(.*\)_Linux.*$/\1/p')
    if [ -z "$version" ]; then
        echo "Warning: 未找到 lucky 补丁文件，跳过更新。" >&2
        return 0
    fi
    
    local makefile_path="$LUCKY_DIR/lucky/Makefile"
    if [ ! -f "$makefile_path" ]; then
        echo "Warning: lucky Makefile not found. Skipping." >&2
        return 0
    fi
    
    local patch_line="\\t[ -f \$(TOPDIR)/../nn6000v2/patches/lucky_${version}_Linux_\$(LUCKY_ARCH)_wanji.tar.gz ] && install -Dm644 \$(TOPDIR)/../nn6000v2/patches/lucky_${version}_Linux_\$(LUCKY_ARCH)_wanji.tar.gz \$(PKG_BUILD_DIR)/\$(PKG_NAME)_\$(PKG_VERSION)_Linux_\$(LUCKY_ARCH).tar.gz"
    
    if grep -q "Build/Prepare" "$makefile_path"; then
        sed -i "/Build\\/Prepare/a\\$patch_line" "$makefile_path"
        sed -i '/wget/d' "$makefile_path"
    else
        echo "Warning: lucky Makefile 中未找到 'Build/Prepare'。跳过。" >&2
    fi
    
    echo "✓ luci-app-lucky 克隆完成"
}

install_adguardhome() {
    local ADGUARDHOME_REPO="https://github.com/wzdddyy/luci-app-adguardhome.git"
    local ADGUARDHOME_DIR="$BUILD_DIR/feeds/openwrt_packages/luci-app-adguardhome"

    rm -rf "$ADGUARDHOME_DIR" 2>/dev/null || true
    if ! git clone --depth=1 "$ADGUARDHOME_REPO" "$ADGUARDHOME_DIR"; then
        echo "错误：从 $ADGUARDHOME_REPO 克隆 luci-app-adguardhome 仓库失败" >&2
        exit 1
    fi

    echo "✓ luci-app-adguardhome 克隆完成"
}

install_easytier() {
    local EASYTIER_REPO="https://github.com/EasyTier/luci-app-easytier.git"
    local EASYTIER_DIR="$BUILD_DIR/feeds/openwrt_packages/luci-app-easytier"

    # 安装依赖
    ./scripts/feeds install -f luci-lib-jsonc
    
    rm -rf "$EASYTIER_DIR" 2>/dev/null || true
    if ! git clone --depth=1 "$EASYTIER_REPO" "$EASYTIER_DIR"; then
        echo "错误：从 $EASYTIER_REPO 克隆 luci-app-easytier 仓库失败" >&2
        exit 1
    fi

    echo "✓ luci-app-easytier 克隆完成"
}

install_oaf() {
    local OAF_REPO="https://github.com/destan19/OpenAppFilter.git"
    local OAF_DIR="$BUILD_DIR/feeds/openwrt_packages/OpenAppFilter"

    ./scripts/feeds install -f kmod-ipt-conntrack kmod-ipt-nat
    
    rm -rf "$OAF_DIR" 2>/dev/null || true
    if ! git clone --depth=1 "$OAF_REPO" "$OAF_DIR"; then
        echo "错误：从 $OAF_REPO 克隆 OpenAppFilter 仓库失败" >&2
        exit 1
    fi

    local oaf_makefile="$OAF_DIR/oaf/Makefile"
    if [ -f "$oaf_makefile" ]; then
        sed -i 's/DEPENDS:=.*oaf/DEPENDS:=+kmod-ipt-conntrack +kmod-ipt-nat/g' "$oaf_makefile"
    fi


    local appfilter_config="$OAF_DIR/open-app-filter/files/etc/config/appfilter"
    if [ -f "$appfilter_config" ]; then
        sed -i "s/option enabled '1'/option enabled '0'/g" "$appfilter_config"
    fi

    local disable_script="$OAF_DIR/luci-app-oaf/root/etc/uci-defaults/99_disable_oaf"
    mkdir -p "$(dirname "$disable_script")"
    cat > "$disable_script" << 'EOF'
#!/bin/sh
[ "$(uci get appfilter.global.enable 2>/dev/null)" = "0" ] && {
    /etc/init.d/appfilter disable
    /etc/init.d/appfilter stop
}
EOF
    chmod +x "$disable_script"

    echo "✓ OpenAppFilter 克隆完成 (服务已禁用)"
}

install_diskman() {
    local path="$BUILD_DIR/feeds/openwrt_packages/luci-app-diskman"
    local repo_url="https://github.com/lisaac/luci-app-diskman.git"
    
    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return
    cd "$BUILD_DIR/feeds/openwrt_packages" || return
    \rm -rf "luci-app-diskman" 2>/dev/null || true

    if ! git clone --filter=blob:none --no-checkout "$repo_url" diskman; then
        echo "错误：从 $repo_url 克隆 diskman 仓库失败" >&2
        exit 1
    fi
    cd diskman || return

    git sparse-checkout init --cone
    git sparse-checkout set applications/luci-app-diskman || return

    git checkout --quiet

    mv applications/luci-app-diskman ../luci-app-diskman || return
    cd .. || return
    \rm -rf diskman 2>/dev/null || true
    cd "$BUILD_DIR"

    sed -i 's/fs-ntfs /fs-ntfs3 /g' "$path/Makefile"
    sed -i '/ntfs-3g-utils /d' "$path/Makefile"
    
    echo "✓ luci-app-diskman 克隆完成"
}

_sync_luci_lib_docker() {
    local repo_url="https://github.com/lisaac/luci-lib-docker.git"
    local luci_lib_docker_dir="$BUILD_DIR/feeds/openwrt_packages/luci-lib-docker"
    
    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return
    
    rm -rf "$luci_lib_docker_dir" 2>/dev/null || true
    if ! git clone --depth=1 "$repo_url" "$luci_lib_docker_dir"; then
        echo "错误：从 $repo_url 克隆 luci-lib-docker 仓库失败" >&2
        exit 1
    fi
    
    echo "✓ luci-lib-docker 克隆完成"
}

install_dockerman() {
    local path="$BUILD_DIR/feeds/openwrt_packages/luci-app-dockerman"
    local repo_url="https://github.com/wzdddyy/luci-app-dockerman.git"
    
    _sync_luci_lib_docker || return
    
    mkdir -p "$BUILD_DIR/feeds/openwrt_packages" || return
    cd "$BUILD_DIR/feeds/openwrt_packages" || return
    \rm -rf "luci-app-dockerman" 2>/dev/null || true

    if ! git clone --filter=blob:none --no-checkout "$repo_url" dockerman; then
        echo "错误：从 $repo_url 克隆 dockerman 仓库失败" >&2
        exit 1
    fi
    cd dockerman || return

    git sparse-checkout init --cone
    git sparse-checkout set applications/luci-app-dockerman || return

    git checkout --quiet

    mv applications/luci-app-dockerman ../luci-app-dockerman || return
    cd .. || return
    \rm -rf dockerman 2>/dev/null || true
    cd "$BUILD_DIR"

    echo "✓ luci-app-dockerman 克隆完成"
}

install_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$BUILD_DIR/feeds/openwrt_packages/luci-app-quickfile"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    if ! git clone --depth 1 "$repo_url" "$target_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-quickfile 仓库失败" >&2
        exit 1
    fi
    echo "✓ luci-app-quickfile 克隆完成"
}

remove_attendedsysupgrade() {
    find "$BUILD_DIR/feeds/luci/collections" -name "Makefile" | while read -r makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
            echo "Removed luci-app-attendedsysupgrade from $makefile"
        fi
    done
}


