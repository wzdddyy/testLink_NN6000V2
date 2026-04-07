#!/usr/bin/env bash
update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi

    echo "=== 修改前的 feeds.conf 内容 ==="
    cat "$FEEDS_PATH"
    echo "================================"

    if ! grep -q "openwrt-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git openwrt-packages https://github.com/kenzok8/openwrt-packages.git" >>"$FEEDS_PATH"
    fi

    if ! grep -q "passwall-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git passwall-packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git" >>"$FEEDS_PATH"
    fi

    echo "=== 修改后的 feeds.conf 内容 ==="
    cat "$FEEDS_PATH"
    echo "================================"

    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    echo "=== 开始执行 feeds update ==="
    ./scripts/feeds update -a 2>&1 | tee /tmp/feeds_update.log
    echo "=== feeds update 完成 ==="
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