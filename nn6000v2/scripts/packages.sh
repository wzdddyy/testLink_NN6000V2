#!/usr/bin/env bash

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        echo "正在更新 golang 软件包..."
        \rm -rf ./feeds/packages/lang/golang
        if ! git clone --depth 1 -b $GOLANG_BRANCH $GOLANG_REPO ./feeds/packages/lang/golang; then
            echo "错误：克隆 golang 仓库 $GOLANG_REPO 失败" >&2
            exit 1
        fi
    fi
}

install_openwrt_packages() {
    ./scripts/feeds install -p openwrt-packages -f taskd luci-lib-xterm luci-lib-taskd \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex \
        smartdns luci-app-smartdns luci-theme-argon luci-app-argon-config
}


install_passwall_packages() {
    echo "正在从 Openwrt-Passwall-packages 仓库安装代理相关依赖..."
    ./scripts/feeds install -p passwall-packages -f chinadns-ng dns2socks geoview hysteria ipt2socks microsocks \
        naiveproxy shadow-tls shadowsocks-libev shadowsocks-rust shadowsocksr-libev simple-obfs sing-box \
        tcping trojan-plus tuic-client v2ray-geodata v2ray-plugin xray-core xray-plugin
}

install_passwall2() {
    local PASSWALL2_REPO="https://github.com/Openwrt-Passwall/openwrt-passwall2.git"
    local PASSWALL2_DIR="$BUILD_DIR/feeds/passwall2"

    echo "正在从 Openwrt-Passwall 仓库安装 luci-app-passwall2..."
    
    rm -rf "$PASSWALL2_DIR"
    if ! git clone --depth=1 -b main "$PASSWALL2_REPO" "$PASSWALL2_DIR"; then
        echo "错误：从 $PASSWALL2_REPO 克隆 luci-app-passwall2 仓库失败" >&2
        exit 1
    fi

    echo "luci-app-passwall2 安装完成"
}

install_fullconenat() {
    ./scripts/feeds install -p packages -f fullconenat-nft fullconenat
}

add_timecontrol() {
    local timecontrol_dir="$BUILD_DIR/package/luci-app-timecontrol"
    local repo_url="https://github.com/sirpdboy/luci-app-timecontrol.git"
    rm -rf "$timecontrol_dir" 2>/dev/null
    echo "正在添加 luci-app-timecontrol..."
    if ! git clone --depth 1 "$repo_url" "$timecontrol_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-timecontrol 仓库失败" >&2
        exit 1
    fi
}


update_lucky() {
    local lucky_repo_url="https://github.com/gdy666/luci-app-lucky.git"
    local target_dir="$BUILD_DIR/feeds/openwrt-packages"
    local lucky_dir="$target_dir/lucky"
    local luci_app_lucky_dir="$target_dir/luci-app-lucky"

    if [ ! -d "$lucky_dir" ] || [ ! -d "$luci_app_lucky_dir" ]; then
        echo "Warning: $lucky_dir 或 $luci_app_lucky_dir 不存在，跳过 lucky 源代码更新。" >&2
    else
        local tmp_dir
        tmp_dir=$(mktemp -d)

        echo "正在从 $lucky_repo_url 稀疏检出 luci-app-lucky 和 lucky..."

        if ! git clone --depth 1 --filter=blob:none --no-checkout "$lucky_repo_url" "$tmp_dir"; then
            echo "错误：从 $lucky_repo_url 克隆仓库失败" >&2
            rm -rf "$tmp_dir"
            return 0
        fi

        pushd "$tmp_dir" >/dev/null
        git sparse-checkout init --cone
        git sparse-checkout set luci-app-lucky lucky || {
            echo "错误：稀疏检出 luci-app-lucky 或 lucky 失败" >&2
            popd >/dev/null
            rm -rf "$tmp_dir"
            return 0
        }
        git checkout --quiet

        \cp -rf "$tmp_dir/luci-app-lucky/." "$luci_app_lucky_dir/"
        \cp -rf "$tmp_dir/lucky/." "$lucky_dir/"

        popd >/dev/null
        rm -rf "$tmp_dir"
        echo "luci-app-lucky 和 lucky 源代码更新完成。"
    fi

    local lucky_conf="$BUILD_DIR/feeds/openwrt-packages/lucky/files/luckyuci"
    if [ -f "$lucky_conf" ]; then
        sed -i "s/option enabled '1'/option enabled '0'/g" "$lucky_conf"
        sed -i "s/option logger '1'/option logger '0'/g" "$lucky_conf"
    fi

    local version
    version=$(find "$BASE_PATH/patches" -name "lucky_*.tar.gz" -printf "%f\n" | head -n 1 | sed -n 's/^lucky_\(.*\)_Linux.*$/\1/p')
    if [ -z "$version" ]; then
        echo "Warning: 未找到 lucky 补丁文件，跳过更新。" >&2
        return 0
    fi

    local makefile_path="$BUILD_DIR/feeds/openwrt-packages/lucky/Makefile"
    if [ ! -f "$makefile_path" ]; then
        echo "Warning: lucky Makefile not found. Skipping." >&2
        return 0
    fi

    echo "正在更新 lucky Makefile..."
    local patch_line="\\t[ -f \$(TOPDIR)/../nn6000v2/patches/lucky_${version}_Linux_\$(LUCKY_ARCH)_wanji.tar.gz ] && install -Dm644 \$(TOPDIR)/../nn6000v2/patches/lucky_${version}_Linux_\$(LUCKY_ARCH)_wanji.tar.gz \$(PKG_BUILD_DIR)/\$(PKG_NAME)_\$(PKG_VERSION)_Linux_\$(LUCKY_ARCH).tar.gz"

    if grep -q "Build/Prepare" "$makefile_path"; then
        sed -i "/Build\\/Prepare/a\\$patch_line" "$makefile_path"
        sed -i '/wget/d' "$makefile_path"
        echo "lucky Makefile 更新完成。"
    else
        echo "Warning: lucky Makefile 中未找到 'Build/Prepare'。跳过。" >&2
    fi
}

install_adguardhome_wzdddyy() {
    local ADGUARDHOME_REPO="https://github.com/wzdddyy/luci-app-adguardhome.git"
    local ADGUARDHOME_DIR="$BUILD_DIR/feeds/luci/applications/luci-app-adguardhome"

    echo "正在从 wzdddyy 仓库安装 luci-app-adguardhome..."
    
    rm -rf "$ADGUARDHOME_DIR"
    if ! git clone --depth=1 "$ADGUARDHOME_REPO" "$ADGUARDHOME_DIR"; then
        echo "错误：从 $ADGUARDHOME_REPO 克隆 luci-app-adguardhome 仓库失败" >&2
        exit 1
    fi

    echo "luci-app-adguardhome 安装完成"
}

install_easytier() {
    local EASYTIER_REPO="https://github.com/EasyTier/luci-app-easytier.git"
    local EASYTIER_DIR="$BUILD_DIR/feeds/luci/applications/luci-app-easytier"

    echo "正在从 EasyTier 官方仓库安装 luci-app-easytier..."
    
    # 安装依赖
    echo "正在安装 EasyTier 依赖..."
    ./scripts/feeds install -p luci -f luci-lib-jsonc
    
    rm -rf "$EASYTIER_DIR"
    if ! git clone --depth=1 "$EASYTIER_REPO" "$EASYTIER_DIR"; then
        echo "错误：从 $EASYTIER_REPO 克隆 luci-app-easytier 仓库失败" >&2
        exit 1
    fi

    echo "luci-app-easytier 安装完成"
}

install_oaf() {
    local OAF_REPO="https://github.com/destan19/OpenAppFilter.git"
    local OAF_DIR="$BUILD_DIR/package/OpenAppFilter"

    echo "正在从 destan19 仓库安装 OpenAppFilter..."
    
    # 安装依赖
    echo "正在安装 OAF 依赖..."
    ./scripts/feeds install -p packages -f kmod-ipt-nat
    
    rm -rf "$OAF_DIR"
    if ! git clone --depth=1 "$OAF_REPO" "$OAF_DIR"; then
        echo "错误：从 $OAF_REPO 克隆 OpenAppFilter 仓库失败" >&2
        exit 1
    fi

    # 默认禁用 OAF 服务
    local oaf_config="$OAF_DIR/open-app-filter/files/etc/config/appfilter"
    if [ -f "$oaf_config" ]; then
        sed -i "s/option enabled '1'/option enabled '0'/g" "$oaf_config"
        echo "OAF 已配置为默认禁用状态"
    fi

    echo "OpenAppFilter 安装完成"
}

update_diskman() {
    local path="$BUILD_DIR/feeds/luci/applications/luci-app-diskman"
    local repo_url="https://github.com/lisaac/luci-app-diskman.git"
    if [ -d "$path" ]; then
        echo "正在更新 diskman..."
        cd "$BUILD_DIR/feeds/luci/applications" || return
        \rm -rf "luci-app-diskman"

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
        \rm -rf diskman
        cd "$BUILD_DIR"

        sed -i 's/fs-ntfs /fs-ntfs3 /g' "$path/Makefile"
        sed -i '/ntfs-3g-utils /d' "$path/Makefile"
    fi
}

_sync_luci_lib_docker() {
    local lib_path="$BUILD_DIR/feeds/luci/libs/luci-lib-docker"
    local repo_url="https://github.com/lisaac/luci-lib-docker.git"
    
    if [ ! -d "$lib_path" ]; then
        echo "正在同步 luci-lib-docker..."
        mkdir -p "$BUILD_DIR/feeds/luci/libs" || return
        cd "$BUILD_DIR/feeds/luci/libs" || return
        
        if ! git clone --filter=blob:none --no-checkout "$repo_url" luci-lib-docker-tmp; then
            echo "错误：从 $repo_url 克隆 luci-lib-docker 仓库失败" >&2
            exit 1
        fi
        cd luci-lib-docker-tmp || return
        
        git sparse-checkout init --cone
        git sparse-checkout set collections/luci-lib-docker || return
        
        git checkout --quiet
        
        mv collections/luci-lib-docker ../luci-lib-docker || return
        cd .. || return
        \rm -rf luci-lib-docker-tmp
        cd "$BUILD_DIR"
        echo "luci-lib-docker 同步完成"
    fi
}

update_dockerman() {
    local path="$BUILD_DIR/feeds/luci/applications/luci-app-dockerman"
    local repo_url="https://github.com/wzdddyy/luci-app-dockerman.git"
    if [ -d "$path" ]; then
        echo "正在更新 dockerman..."
        _sync_luci_lib_docker || return
        
        cd "$BUILD_DIR/feeds/luci/applications" || return
        \rm -rf "luci-app-dockerman"

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
        \rm -rf dockerman
        cd "$BUILD_DIR"

        echo "dockerman 更新完成"
    fi
}

add_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$BUILD_DIR/package/emortal/quickfile"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    echo "正在添加 luci-app-quickfile..."
    if ! git clone --depth 1 "$repo_url" "$target_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-quickfile 仓库失败" >&2
        exit 1
    fi
}

remove_attendedsysupgrade() {
    find "$BUILD_DIR/feeds/luci/collections" -name "Makefile" | while read -r makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
            echo "Removed luci-app-attendedsysupgrade from $makefile"
        fi
    done
}

update_package() {
    local dir=$(find "$BUILD_DIR/package" \( -type d -o -type l \) -name "$1")
    if [ -z "$dir" ]; then
        return 0
    fi
    local branch="$2"
    if [ -z "$branch" ]; then
        branch="releases"
    fi
    local mk_path="$dir/Makefile"
    if [ -f "$mk_path" ]; then
        local PKG_REPO=$(grep -oE "^PKG_GIT_URL.*github.com(/[-_a-zA-Z0-9]{1,}){2}" "$mk_path" | awk -F"/" '{print $(NF - 1) "/" $NF}')
        if [ -z "$PKG_REPO" ]; then
            PKG_REPO=$(grep -oE "^PKG_SOURCE_URL.*github.com(/[-_a-zA-Z0-9]{1,}){2}" "$mk_path" | awk -F"/" '{print $(NF - 1) "/" $NF}')
            if [ -z "$PKG_REPO" ]; then
                echo "错误：无法从 $mk_path 提取 PKG_REPO" >&2
                return 1
            fi
        fi
        local PKG_VER
        if ! PKG_VER=$(curl -fsSL "https://api.github.com/repos/$PKG_REPO/$branch" | jq -r '.[0] | .tag_name // .name'); then
            echo "错误：从 https://api.github.com/repos/$PKG_REPO/$branch 获取版本信息失败" >&2
            return 1
        fi
        if [ -n "$3" ]; then
            PKG_VER="$3"
        fi
        local PKG_VER_CLEAN
        PKG_VER_CLEAN=$(echo "$PKG_VER" | sed 's/^v//')
        if grep -q "^PKG_GIT_SHORT_COMMIT:=" "$mk_path"; then
            local PKG_GIT_URL_RAW
            PKG_GIT_URL_RAW=$(awk -F"=" '/^PKG_GIT_URL:=/ {print $NF}' "$mk_path")
            local PKG_GIT_REF_RAW
            PKG_GIT_REF_RAW=$(awk -F"=" '/^PKG_GIT_REF:=/ {print $NF}' "$mk_path")

            if [ -z "$PKG_GIT_URL_RAW" ] || [ -z "$PKG_GIT_REF_RAW" ]; then
                echo "错误：$mk_path 缺少 PKG_GIT_URL 或 PKG_GIT_REF，无法更新 PKG_GIT_SHORT_COMMIT" >&2
                return 1
            fi

            local PKG_GIT_REF_RESOLVED
            PKG_GIT_REF_RESOLVED=$(echo "$PKG_GIT_REF_RAW" | sed "s/\$(PKG_VERSION)/$PKG_VER_CLEAN/g; s/\${PKG_VERSION}/$PKG_VER_CLEAN/g")

            local PKG_GIT_REF_TAG="${PKG_GIT_REF_RESOLVED#refs/tags/}"

            local COMMIT_SHA
            local LS_REMOTE_OUTPUT
            LS_REMOTE_OUTPUT=$(git ls-remote "https://$PKG_GIT_URL_RAW" "refs/tags/${PKG_GIT_REF_TAG}" "refs/tags/${PKG_GIT_REF_TAG}^{}" 2>/dev/null)
            COMMIT_SHA=$(echo "$LS_REMOTE_OUTPUT" | awk '/\^\{\}$/ {print $1; exit}')
            if [ -z "$COMMIT_SHA" ]; then
                COMMIT_SHA=$(echo "$LS_REMOTE_OUTPUT" | awk 'NR==1{print $1}')
            fi
            if [ -z "$COMMIT_SHA" ]; then
                COMMIT_SHA=$(git ls-remote "https://$PKG_GIT_URL_RAW" "${PKG_GIT_REF_RESOLVED}^{}" 2>/dev/null | awk 'NR==1{print $1}')
            fi
            if [ -z "$COMMIT_SHA" ]; then
                COMMIT_SHA=$(git ls-remote "https://$PKG_GIT_URL_RAW" "$PKG_GIT_REF_RESOLVED" 2>/dev/null | awk 'NR==1{print $1}')
            fi
            if [ -z "$COMMIT_SHA" ]; then
                echo "错误：无法从 https://$PKG_GIT_URL_RAW 获取 $PKG_GIT_REF_RESOLVED 的提交哈希" >&2
                return 1
            fi

            local SHORT_COMMIT
            SHORT_COMMIT=$(echo "$COMMIT_SHA" | cut -c1-7)
            sed -i "s/^PKG_GIT_SHORT_COMMIT:=.*/PKG_GIT_SHORT_COMMIT:=$SHORT_COMMIT/g" "$mk_path"
        fi
        PKG_VER=$(echo "$PKG_VER" | grep -oE "[\.0-9]{1,}")

        local PKG_NAME=$(awk -F"=" '/PKG_NAME:=/ {print $NF}' "$mk_path" | grep -oE "[-_:/\$\(\)\?\.a-zA-Z0-9]{1,}")
        local PKG_SOURCE=$(awk -F"=" '/PKG_SOURCE:=/ {print $NF}' "$mk_path" | grep -oE "[-_:/\$\(\)\?\.a-zA-Z0-9]{1,}")
        local PKG_SOURCE_URL=$(awk -F"=" '/PKG_SOURCE_URL:=/ {print $NF}' "$mk_path" | grep -oE "[-_:/\$\(\)\{\}\?\.a-zA-Z0-9]{1,}")
        local PKG_GIT_URL=$(awk -F"=" '/PKG_GIT_URL:=/ {print $NF}' "$mk_path")
        local PKG_GIT_REF=$(awk -F"=" '/PKG_GIT_REF:=/ {print $NF}' "$mk_path")

        PKG_SOURCE_URL=${PKG_SOURCE_URL//\$\(PKG_GIT_URL\)/$PKG_GIT_URL}
        PKG_SOURCE_URL=${PKG_SOURCE_URL//\$\(PKG_GIT_REF\)/$PKG_GIT_REF}
        PKG_SOURCE_URL=${PKG_SOURCE_URL//\$\(PKG_NAME\)/$PKG_NAME}
        PKG_SOURCE_URL=$(echo "$PKG_SOURCE_URL" | sed "s/\${PKG_VERSION}/$PKG_VER/g; s/\$(PKG_VERSION)/$PKG_VER/g")
        PKG_SOURCE=${PKG_SOURCE//\$\(PKG_NAME\)/$PKG_NAME}
        PKG_SOURCE=${PKG_SOURCE//\$\(PKG_VERSION\)/$PKG_VER}

        local PKG_HASH
        if ! PKG_HASH=$(curl -fsSL "$PKG_SOURCE_URL""$PKG_SOURCE" | sha256sum | cut -b -64); then
            echo "错误：从 $PKG_SOURCE_URL$PKG_SOURCE 获取软件包哈希失败" >&2
            return 1
        fi

        sed -i 's/^PKG_VERSION:=.*/PKG_VERSION:='$PKG_VER'/g' "$mk_path"
        sed -i 's/^PKG_HASH:=.*/PKG_HASH:='$PKG_HASH'/g' "$mk_path"

        echo "更新软件包 $1 到 $PKG_VER $PKG_HASH"
    fi
}
