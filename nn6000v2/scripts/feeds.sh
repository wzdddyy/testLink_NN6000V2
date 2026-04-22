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
    
    # 先更新 feeds 索引
    echo "更新 feeds 索引..."
    ./scripts/feeds update -i
    
    # 先安装 openwrt-packages 中的包
    echo "安装 openwrt-packages 包..."
    install_openwrt_packages
    install_fullconenat
    
    # 安装其他 feeds 的包
    for dir in "$BUILD_DIR"/feeds/*; do
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [[ ! "$dir" == *.index ]] && [[ ! "$dir" == *.targetindex ]]; then
            local feed_name=$(basename "$dir")
            if [[ "$feed_name" != "openwrt_packages" ]]; then
                ./scripts/feeds install -f -ap "$feed_name"
            fi
        fi
    done
    
    echo "=== feeds 包安装完成 ==="
    cd - >/dev/null || exit 1
}