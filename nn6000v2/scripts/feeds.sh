#!/usr/bin/env bash

# 加载检测和清理脚本
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
BASE_PATH=${BASE_PATH:-$(dirname "$SCRIPT_DIR")}
CHECK_CLEAN_SCRIPT="$BASE_PATH/scripts/check_and_clean.sh"

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
    
    # 动态检测所有已存在的 feeds
    echo "检测 feeds 仓库更新..."
    for feed_dir in "$BUILD_DIR"/feeds/*/; do
        if [ -d "$feed_dir/.git" ]; then
            feed_name=$(basename "$feed_dir")
            feed_rel_path="./feeds/$feed_name"
            
            if [ -f "$CHECK_CLEAN_SCRIPT" ]; then
                (cd "$BUILD_DIR" && bash "$CHECK_CLEAN_SCRIPT" "$feed_name" "$feed_rel_path" "git")
            fi
        fi
    done
    
    # 执行 feeds update
    (cd "$BUILD_DIR" && ./scripts/feeds clean && ./scripts/feeds update -a)
    
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