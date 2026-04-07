#!/usr/bin/env bash
update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi
    # 备份原始文件
    cp "$FEEDS_PATH" "$FEEDS_PATH.bak"
    
    # 删除注释行和packages_ext行
    sed -i '/^#/d' "$FEEDS_PATH"
    sed -i '/packages_ext/d' "$FEEDS_PATH"

    # 添加openwrt-packages源
    if ! grep -q "openwrt-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git openwrt-packages https://github.com/kenzok8/openwrt-packages;master" >>"$FEEDS_PATH"
    fi

    # 添加passwall-packages源
    if ! grep -q "openwrt-passwall-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git passwall-packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages;main" >>"$FEEDS_PATH"
    fi

    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    ./scripts/feeds update -a
}

install_feeds() {
    ./scripts/feeds update -i
    for dir in $BUILD_DIR/feeds/*; do
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [[ ! "$dir" == *.index ]] && [[ ! "$dir" == *.targetindex ]]; then
            if [[ $(basename "$dir") == "openwrt-packages" ]]; then
                install_openwrt_packages
                install_fullconenat
            elif [[ $(basename "$dir") == "passwall-packages" ]]; then
                install_passwall_packages
            else
                ./scripts/feeds install -f -ap $(basename "$dir")
            fi
        fi
    done
}
