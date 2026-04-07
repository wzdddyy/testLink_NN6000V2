#!/usr/bin/env bash
update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi
    
    # 创建临时文件进行修改
    local TEMP_FILE=$(mktemp)
    
    # 删除注释行和包含 packages_ext 的行
    grep -v "^#" "$FEEDS_PATH" | grep -v "packages_ext" > "$TEMP_FILE"
    
    # 添加 openwrt-packages 源
    if ! grep -q "openwrt-packages" "$TEMP_FILE"; then
        echo "" >>"$TEMP_FILE"
        echo "src-git openwrt-packages https://github.com/kenzok8/openwrt-packages" >>"$TEMP_FILE"
    fi

    # 添加 passwall-packages 源
    if ! grep -q "passwall-packages" "$TEMP_FILE"; then
        echo "" >>"$TEMP_FILE"
        echo "src-git passwall-packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages" >>"$TEMP_FILE"
    fi
    
    # 用临时文件替换原文件
    mv "$TEMP_FILE" "$FEEDS_PATH"

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
