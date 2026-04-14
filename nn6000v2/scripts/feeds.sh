#!/usr/bin/env bash
update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi

    sed -i '/^src-link/d' "$FEEDS_PATH"

    if ! grep -q "openwrt-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git openwrt_packages https://github.com/kenzok8/openwrt-packages.git" >>"$FEEDS_PATH"
    fi

    # 添加 nikki feeds 源
    if ! grep -q "nikkinikki-org/OpenWrt-nikki" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >>"$FEEDS_PATH"
    fi


    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    echo "=== 开始执行 feeds update ==="
    ./scripts/feeds clean
    ./scripts/feeds update -a
    echo "=== feeds update 完成 ==="
}

install_feeds() {
    cd "$BUILD_DIR" || exit 1
    
    echo "=== 开始安装 feeds 包 ==="
    
    # 使用 -a 安装所有 feeds 包
    echo "安装所有 feeds 包..."
    ./scripts/feeds install -a
    
    echo "=== feeds 包安装完成 ==="
    cd - >/dev/null || exit 1
}