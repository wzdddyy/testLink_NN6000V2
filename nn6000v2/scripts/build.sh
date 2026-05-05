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
INI_FILE="$BASE_PATH/configs/$Dev.ini"

if [[ ! -f $CONFIG_FILE ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {print $2}' "$INI_FILE"
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

REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_DIR=$(read_ini_by_key "BUILD_DIR")
COMMIT_HASH=$(read_ini_by_key "COMMIT_HASH")
COMMIT_HASH=${COMMIT_HASH:-none}

if [[ -d action_build ]]; then
    BUILD_DIR="action_build"
fi

"$BASE_PATH/scripts/update.sh" "$REPO_URL" "$REPO_BRANCH" "$BUILD_DIR" "$COMMIT_HASH"

apply_config
remove_uhttpd_dependency

# 修复各种编译问题
fix_compilation_issues() {
    echo "=== 修复编译问题 ==="
    
    # 1. 修复 mac80211 ath11k 补丁应用失败问题
    local mac80211_patch_dir="$BASE_PATH/../$BUILD_DIR/package/kernel/mac80211/patches/ath11k"
    if [ -d "$mac80211_patch_dir" ]; then
        local problematic_patch="$mac80211_patch_dir/990-ath11k-clamp-reg-rule-bandwidth.patch"
        if [ -f "$problematic_patch" ]; then
            echo "⚠️ 删除有问题的 ath11k 补丁：990-ath11k-clamp-reg-rule-bandwidth.patch"
            rm -f "$problematic_patch"
        fi
    fi
    
    # 2. 修复 rust 编译问题
    local rust_makefile="$BASE_PATH/../$BUILD_DIR/feeds/packages/lang/rust/Makefile"
    if [ -f "$rust_makefile" ]; then
        sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$rust_makefile"
        echo "✓ 修复 rust 编译配置"
    fi
    
    # 3. 修复 coremark 编译问题
    local coremark_makefile="$BASE_PATH/../$BUILD_DIR/feeds/packages/utils/coremark/Makefile"
    if [ -f "$coremark_makefile" ]; then
        sed -i 's/mkdir \$/mkdir -p \$/g' "$coremark_makefile"
        echo "✓ 修复 coremark 编译配置"
    fi
    
    # 4. 修复 kconfig 递归依赖问题
    local package_metadata="$BASE_PATH/../$BUILD_DIR/scripts/package-metadata.pl"
    if [ -f "$package_metadata" ]; then
        sed -i 's/<PACKAGE_\$pkgname/!=y/g' "$package_metadata"
        echo "✓ 修复 kconfig 递归依赖"
    fi
    
    # 5. 修复可能的 openssl ktls 依赖问题
    local openssl_config="$BASE_PATH/../$BUILD_DIR/package/libs/openssl/Config.in"
    if [ -f "$openssl_config" ]; then
        if ! grep -q 'depends on PACKAGE_kmod-tls' "$openssl_config"; then
            sed -i 's/select PACKAGE_kmod-tls/depends on PACKAGE_kmod-tls/g' "$openssl_config"
            sed -i '/depends on PACKAGE_kmod-tls/a\\tdefault y if PACKAGE_kmod-tls' "$openssl_config"
            echo "✓ 修复 openssl ktls 依赖"
        fi
    fi
    
    # 6. 禁用有问题的 onionshare-cli
    echo "CONFIG_PACKAGE_onionshare-cli=n" >> "$BASE_PATH/../$BUILD_DIR/.config"
    echo "✓ 禁用 onionshare-cli"
    
    echo "✓ 编译问题修复完成"
}

# Modify kernel size to 12MB for ipq60xx devices
modify_kernel_size() {
    local ipq60xx_mk_path="$BASE_PATH/../$BUILD_DIR/target/linux/qualcommax/image/ipq60xx.mk"
    
    if [ -f "$ipq60xx_mk_path" ]; then
        # Change KERNEL_SIZE from 6144k to 12288k for link_nn6000 devices
        sed -i '/link_nn6000-common/,/endef/{s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/g}' "$ipq60xx_mk_path"
        echo "Updated KERNEL_SIZE to 12288k (12MB) for link_nn6000 devices"
    fi
}

fix_compilation_issues
modify_kernel_size

cd "$BASE_PATH/../$BUILD_DIR"
make defconfig

if [[ $Build_Mod == "debug" ]]; then
    exit 0
fi

TARGET_DIR="$BASE_PATH/../$BUILD_DIR/bin/targets"
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
