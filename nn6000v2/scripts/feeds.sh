#!/usr/bin/env bash
update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi
    # 删除注释行
    sed -i '/^#/d' "$FEEDS_PATH"
    
    # 删除包含 packages_ext 的行（如果存在）
    grep -q "packages_ext" "$FEEDS_PATH" && sed -i '/packages_ext/d' "$FEEDS_PATH"

    # 添加 openwrt-packages 源
    if ! grep -q "openwrt-packages" "$FEEDS_PATH"; then
        echo "" >>"$FEEDS_PATH"
        echo "src-git openwrt-packages https://github.com/kenzok8/openwrt-packages" >>"$FEEDS_PATH"
    fi

    # 添加 passwall-packages 源
    if ! grep -q "passwall-packages" "$FEEDS_PATH"; then
        echo "" >>"$FEEDS_PATH"
        echo "src-git passwall-packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages" >>"$FEEDS_PATH"
    fi

    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    cd "$BUILD_DIR" || exit 1
    ./scripts/feeds update -a
    cd - >/dev/null || exit 1
}

install_feeds() {
    cd "$BUILD_DIR" || exit 1
    ./scripts/feeds update -i
    for dir in "$BUILD_DIR"/feeds/*; do
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [[ ! "$dir" == *.index ]] && [[ ! "$dir" == *.targetindex ]]; then
            if [[ $(basename "$dir") == "openwrt-packages" ]]; then
                install_openwrt_packages
                install_fullconenat
            elif [[ $(basename "$dir") == "passwall-packages" ]]; then
                install_passwall_packages
            else
                ./scripts/feeds install -f -ap "$(basename "$dir")"
            fi
        fi
    done
    cd - >/dev/null || exit 1
}
