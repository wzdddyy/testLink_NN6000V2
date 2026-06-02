#!/usr/bin/env bash

set -e

# Determine nn6000v2 path
if [ -d "nn6000v2" ]; then
    NN6000V2_PATH="nn6000v2"
elif [ -d "../nn6000v2" ]; then
    NN6000V2_PATH="../nn6000v2"
else
    echo "Error: nn6000v2 directory not found!"
    exit 1
fi

BASE_PATH=$(cd "$NN6000V2_PATH" && pwd)

Dev=$1
Build_Mod=$2

CONFIG_FILE="$BASE_PATH/configs/$Dev.config"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

# Use environment variables or defaults for repo config
REPO_URL=${REPO_URL:-https://github.com/VIKINGYFY/immortalwrt.git}
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_DIR=${BUILD_DIR:-imm-nss}
COMMIT_HASH=${COMMIT_HASH:-none}

# Shared firmware patterns used by find commands (avoid 4x duplication)
read -r -d '' FIRMWARE_PATTERNS <<'EOF'
\( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \)
EOF

# WiFi package names for dual-version (nowifi) builds
WIFI_PACKAGES=(
    CONFIG_PACKAGE_kmod-ath
    CONFIG_PACKAGE_kmod-ath11k
    CONFIG_PACKAGE_kmod-ath11k-ahb
    CONFIG_PACKAGE_kmod-ath11k-pci
    CONFIG_PACKAGE_ath11k-firmware-ipq6018-ddwrt
    CONFIG_PACKAGE_ath11k-firmware-qcn9074-ddwrt
)

# Toggle WiFi packages in config: on->off or off->on
toggle_wifi_packages() {
    local from_val="$1" to_val="$2"
    for pkg in "${WIFI_PACKAGES[@]}"; do
        sed -i "s/^${pkg}=${from_val}\$/${pkg}=${to_val}/" "$CONFIG_FILE"
    done
}

remove_uhttpd_dependency() {
    local config_path="$BASE_PATH/../$BUILD_DIR/.config"
    local luci_makefile_path="$BASE_PATH/../$BUILD_DIR/feeds/luci/collections/luci/Makefile"

    if grep -q "CONFIG_PACKAGE_luci-app-quickfile=y" "$config_path"; then
        if [ -f "$luci_makefile_path" ]; then
            sed -i '/luci-light/d' "$luci_makefile_path"
            echo "Removed uhttpd (luci-light) dependency as luci-app-quickfile (nginx) is enabled."
        fi
    fi
}

apply_config() {
    \cp -f "$CONFIG_FILE" "$BASE_PATH/../$BUILD_DIR/.config"

    cat "$BASE_PATH/configs/docker_deps.config" >> "$BASE_PATH/../$BUILD_DIR/.config"
}

fix_netfilter_kmod_clash() {
    local include_netfilter_mk="$BASE_PATH/../$BUILD_DIR/include/netfilter.mk"
    local netfilter_mk="$BASE_PATH/../$BUILD_DIR/package/kernel/linux/modules/netfilter.mk"

    if [ ! -f "$include_netfilter_mk" ]; then
        echo "Netfilter include file not found: $include_netfilter_mk" >&2
        return 1
    fi

    if [ ! -f "$netfilter_mk" ]; then
        echo "Netfilter makefile not found: $netfilter_mk" >&2
        return 1
    fi

    if grep -q 'CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables, ge 6.12' "$include_netfilter_mk" && \
       grep -q 'CONFIG_IP6_NF_IPTABLES_LEGACY, $(P_V6)ip6_tables, ge 6.12' "$include_netfilter_mk" && \
       grep -q 'DEPENDS:=+(!(LINUX_6_12||LINUX_6_18)):kmod-iptables' "$netfilter_mk"; then
        echo "Netfilter kmod clash workaround already applied"
        return 0
    fi

    if grep -q '$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables),))' "$include_netfilter_mk"; then
        echo "Updating NF_IPT mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables),))@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables, lt 6.12),))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP_NF_IPTABLES, $(P_V4)ip_tables, lt 6\.12)/a$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT,CONFIG_IP_NF_IPTABLES_LEGACY, $(P_V4)ip_tables, ge 6.12),))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET)))' "$include_netfilter_mk"; then
        echo "Updating IPT_CORE userland mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET)))@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, lt 6.12)))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP_NF_IPTABLES, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, lt 6\.12))/a$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_CORE,CONFIG_IP_NF_IPTABLES_LEGACY, xt_standard ipt_icmp xt_tcp xt_udp xt_comment xt_set xt_SET, ge 6.12)))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables),))' "$include_netfilter_mk"; then
        echo "Updating NF_IPT6 mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables),))@$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables, lt 6.12),))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP6_NF_IPTABLES, $(P_V6)ip6_tables, lt 6\.12)/a$(eval $(if $(NF_KMOD),$(call nf_add,NF_IPT6,CONFIG_IP6_NF_IPTABLES_LEGACY, $(P_V6)ip6_tables, ge 6.12),))' "$include_netfilter_mk"
    fi

    if grep -q '$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6)))' "$include_netfilter_mk"; then
        echo "Updating IPT_IPV6 userland mapping for Linux 6.12/6.18..."
        sed -i 's@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6)))@$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES, ip6t_icmp6, lt 6.12)))@' "$include_netfilter_mk"
        sed -i '/CONFIG_IP6_NF_IPTABLES, ip6t_icmp6, lt 6\.12))/a$(eval $(if $(NF_KMOD),,$(call nf_add,IPT_IPV6,CONFIG_IP6_NF_IPTABLES_LEGACY, ip6t_icmp6, ge 6.12)))' "$include_netfilter_mk"
    fi

    if grep -q 'DEPENDS:=+!LINUX_6_12:kmod-iptables' "$netfilter_mk"; then
        echo "Applying netfilter kmod clash workaround for Linux 6.12/6.18..."
        sed -i 's/DEPENDS:=+!LINUX_6_12:kmod-iptables/DEPENDS:=+(!(LINUX_6_12||LINUX_6_18)):kmod-iptables/' "$netfilter_mk"
        return 0
    fi

    echo "Netfilter kmod clash workaround applied successfully"
}

if [[ -d action_build ]]; then
    BUILD_DIR="action_build"
fi

"$BASE_PATH/scripts/update.sh" "$REPO_URL" "$REPO_BRANCH" "$BUILD_DIR" "$COMMIT_HASH"

apply_config
fix_netfilter_kmod_clash
remove_uhttpd_dependency

# Modify kernel size to 12MB for ipq60xx devices
modify_kernel_size() {
    local ipq60xx_mk_path="$BASE_PATH/../$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    
    if [ -f "$ipq60xx_mk_path" ]; then
        # Change KERNEL_SIZE from 6144k to 12288k for link_nn6000 devices
        sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g}' "$ipq60xx_mk_path"
        echo "Updated KERNEL_SIZE to 12288k (12MB) for link_nn6000 devices"
    fi
}

modify_kernel_size

cd "$BASE_PATH/../$BUILD_DIR"
make defconfig

if [[ $Build_Mod == "debug" ]]; then
    exit 0
fi

TARGET_DIR="$BASE_PATH/../$BUILD_DIR/bin/targets"
if [[ -d $TARGET_DIR && "$Dev" != *"nowifi"* ]]; then
    find "$TARGET_DIR" -type f $FIRMWARE_PATTERNS -exec rm -f {} +
fi

if [[ "$Dev" != *"nowifi"* ]]; then
    make download -j$(nproc)
    make -j$(($(nproc) + 1)) || make -j1 V=s
fi

if [[ -d action_build ]]; then
    make clean
fi

# 如果是正常版本编译，完成后自动编译无 WiFi 版本
if [[ "$Dev" != *"nowifi"* ]]; then
    echo ""
    echo "=============================================="
    echo "  版本编译完成！"
    echo "  开始编译无 WiFi 版本..."
    echo "=============================================="
    echo ""
    
    # 先复制带 WiFi 版本到最终目录
    FIRMWARE_DIR="$BASE_PATH/../firmware"
    \rm -rf "$FIRMWARE_DIR"
    mkdir -p "$FIRMWARE_DIR"
    find "$TARGET_DIR" -type f $FIRMWARE_PATTERNS -exec cp -f {} "$FIRMWARE_DIR/" \;
    
    # 直接修改当前配置文件（禁用 WiFi）
    cd "$BASE_PATH/../$BUILD_DIR"
    
    echo "应用配置..."
    toggle_wifi_packages "y" "n"
    
    cp -f "$CONFIG_FILE" .config
    make defconfig
    
    echo "编译无 WiFi 版本..."
    make -j$(($(nproc) + 1)) || make -j1 V=s
    
    echo "复制固件..."
    find "$TARGET_DIR" -type f $FIRMWARE_PATTERNS | while read -r file; do
        filename=$(basename "$file")
        new_filename=$(echo "$filename" | sed 's/\.\([^.]*\)$/_nowifi.\1/')
        echo "Copying: $filename -> $new_filename"
        cp -f "$file" "$FIRMWARE_DIR/$new_filename"
    done
    
    # 恢复配置文件
    echo "恢复配置文件..."
    toggle_wifi_packages "n" "y"
    
    echo ""
    echo "=============================================="
    echo "  双版本已编译完成！"
    echo "  输出目录：$FIRMWARE_DIR"
    echo "=============================================="
    echo ""
    
    if [[ -d action_build ]]; then
        make clean
    fi
    
    exit 0
fi
