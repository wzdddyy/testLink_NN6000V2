#!/usr/bin/env bash

set -e

# Determine nn6000v2 path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"

Dev=$1
Build_Mod=$2

CONFIG_FILE="$BASE_PATH/configs/$Dev.config"
INI_FILE="$BASE_PATH/configs/$Dev.ini"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi


remove_uhttpd_dependency() {
    local config_path="$BUILD_DIR/.config"
    local luci_makefile_path="$BUILD_DIR/feeds/luci/collections/luci/Makefile"

    if grep -q "CONFIG_PACKAGE_luci-app-quickfile=y" "$config_path"; then
        if [ -f "$luci_makefile_path" ]; then
            sed -i '/luci-light/d' "$luci_makefile_path"
            echo "Removed uhttpd (luci-light) dependency as luci-app-quickfile (nginx) is enabled."
        fi
    fi
}

apply_config() {
    \cp -f "$CONFIG_FILE" "$BUILD_DIR/.config"
    
    cat "$BASE_PATH/configs/docker_deps.config" >> "$BUILD_DIR/.config"
}

# 使用环境变量配置（工作流中已定义默认值）
REPO_URL="${REPO_URL:-https://github.com/VIKINGYFY/immortalwrt.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
BUILD_DIR="${BUILD_DIR:-imm-nss}"
COMMIT_HASH="${COMMIT_HASH:-none}"

# 确保 BUILD_DIR 是绝对路径
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$BASE_PATH/../$BUILD_DIR"
fi
# 规范化路径（处理 .. 和 .）
BUILD_DIR=$(readlink -f "$BUILD_DIR" 2>/dev/null || echo "$BUILD_DIR")

# 创建 repo_flag 用于缓存识别
echo "$REPO_URL/$REPO_BRANCH" >"$BASE_PATH/../repo_flag"

"$BASE_PATH/scripts/update.sh" "$REPO_URL" "$REPO_BRANCH" "$BUILD_DIR" "$COMMIT_HASH"

apply_config
remove_uhttpd_dependency

# Modify kernel size to 12MB for ipq60xx devices
modify_kernel_size() {
    local ipq60xx_mk_path="$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    
    if [ -f "$ipq60xx_mk_path" ]; then
        # Change KERNEL_SIZE from 6144k to 12288k for link_nn6000 devices
        sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g}' "$ipq60xx_mk_path"
        echo "Updated KERNEL_SIZE to 12288k (12MB) for link_nn6000 devices"
    fi
}

modify_kernel_size

cd "$BUILD_DIR"
make defconfig

if [[ $Build_Mod == "debug" ]]; then
    exit 0
fi

TARGET_DIR="$BUILD_DIR/bin/targets"
if [[ -d $TARGET_DIR ]]; then
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec rm -f {} +
fi

make download -j$(($(nproc) * 2))
make -j$(($(nproc) + 1)) || make -j1 V=s

FIRMWARE_DIR="$BASE_PATH/../firmware"
\rm -rf "$FIRMWARE_DIR"
mkdir -p "$FIRMWARE_DIR"
find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec cp -f {} "$FIRMWARE_DIR/" \;
\rm -f "$BASE_PATH/../firmware/Packages.manifest" 2>/dev/null

if [[ -d action_build ]]; then
    make clean
fi
