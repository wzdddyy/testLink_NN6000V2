#!/usr/bin/env bash

update_feeds() {
    local FEEDS_PATH="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        FEEDS_PATH="$BUILD_DIR/feeds.conf"
    fi
    

    sed -i '/^#/d' "$FEEDS_PATH"
    sed -i '/packages_ext/d' "$FEEDS_PATH"
    

    if ! grep -q "luna-action-packages" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git luna https://github.com/lunatickochiya/luna-action-packages.git;master" >>"$FEEDS_PATH"
    fi
    

    if ! grep -q "openwrt-passwall" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo "src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall;main" >>"$FEEDS_PATH"
    fi
    

    if ! grep -q "openwrt_bandix" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo 'src-git openwrt_bandix https://github.com/timsaya/openwrt-bandix.git;main' >>"$FEEDS_PATH"
    fi
    
    if ! grep -q "luci_app_bandix" "$FEEDS_PATH"; then
        [ -z "$(tail -c 1 "$FEEDS_PATH")" ] || echo "" >>"$FEEDS_PATH"
        echo 'src-git luci_app_bandix https://github.com/timsaya/luci-app-bandix.git;main' >>"$FEEDS_PATH"
    fi
    
    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi
    
    # 先更新 passwall
    echo "Updating passwall feed..."
    ./scripts/feeds update passwall || {
        echo "警告：passwall feed 更新失败，继续更新其他 feed" >&2
    }
    
    # 更新 bandix feeds
    echo "Updating openwrt_bandix feed..."
    ./scripts/feeds update openwrt_bandix || {
        echo "警告：openwrt_bandix feed 更新失败，继续更新其他 feed" >&2
    }
    
    echo "Updating luci_app_bandix feed..."
    ./scripts/feeds update luci_app_bandix || {
        echo "警告：luci_app_bandix feed 更新失败，继续更新其他 feed" >&2
    }
    
    # 最后更新 luna feed
    echo "Updating luna feed..."
    ./scripts/feeds update luna || {
        echo "错误：luna feed 更新失败" >&2
        return 1
    }
}

install_feeds() {
    for dir in $BUILD_DIR/feeds/*; do
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [[ ! "$dir" == *.index ]] && [[ ! "$dir" == *.targetindex ]]; then
            if [[ $(basename "$dir") == "luna" ]]; then
                # Skip luna packages that are already installed/updated individually
                install_luna
                install_fullconenat
            elif [[ $(basename "$dir") == "passwall" ]]; then
                # Skip passwall if already installed individually
                install_passwall
            else
                ./scripts/feeds install -f -ap $(basename "$dir")
            fi
        fi
    done
    echo "Feeds installation completed"
}
