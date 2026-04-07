#!/usr/bin/env bash

update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi

    sed -i '/^[[:space:]]*$/d' "$FEEDS_PATH"
    sed -i '/packages_ext/d' "$FEEDS_PATH"
    printf '\n' >> "$FEEDS_PATH"

    # 添加 openwrt-packages 源
    echo "src-git openwrt-packages https://github.com/kenzok8/openwrt-packages" >>"$FEEDS_PATH"

    # 添加 passwall-packages 源
    echo "src-git passwall-packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages" >>"$FEEDS_PATH"

    # 再清理一遍空行
    sed -i '/^[[:space:]]*$/d' "$FEEDS_PATH"

    # 修复 bpf.mk
    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    # 执行更新
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