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

if [[ $Build_Mod == "nowifi" ]]; then
    CONFIG_FILE="$BASE_PATH/configs/kernel/${Dev}_nowifi.config"
else
    CONFIG_FILE="$BASE_PATH/configs/kernel/$Dev.config"
fi

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
    local temp_config="$BASE_PATH/../$BUILD_DIR/.config.tmp"
    local final_config="$BASE_PATH/../$BUILD_DIR/.config"
    
    > "$temp_config"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ ^include[[:space:]]+(.+)$ ]]; then
            local include_file="${BASH_REMATCH[1]}"
            local include_path="$BASE_PATH/configs/kernel/$include_file"
            
            if [[ -f "$include_path" ]]; then
                cat "$include_path" >> "$temp_config"
                echo "# Included: $include_file" >> "$temp_config"
            else
                echo "# Warning: Include file not found: $include_path" >> "$temp_config"
            fi
        else
            echo "$line" >> "$temp_config"
        fi
    done < "$CONFIG_FILE"
    
    \cp -f "$temp_config" "$final_config"
    rm -f "$temp_config"
    
    if grep -qE "(ipq60xx|ipq807x)" "$final_config" &&
        ! grep -q "CONFIG_GIT_MIRROR" "$final_config"; then
        cat "$BASE_PATH/configs/kernel/nss.config" >> "$final_config"
    fi

    cat "$BASE_PATH/configs/kernel/docker_deps.config" >> "$final_config"
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
if [[ -d $TARGET_DIR ]]; then
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec rm -f {} +
fi

if [[ $Build_Mod == "nowifi" ]] && [[ -d $TARGET_DIR ]] && [[ "$(ls -A $TARGET_DIR 2>/dev/null)" ]]; then
    echo "=== 检测到已编译内容，跳过编译，直接打包无 WiFi 版本 ==="
else
    make download -j$(($(nproc) * 2))
    make -j$(($(nproc) + 1)) || make -j1 V=s
fi

FIRMWARE_DIR="$BASE_PATH/../firmware"
mkdir -p "$FIRMWARE_DIR"

if [[ $Build_Mod == "nowifi" ]]; then
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) | while read -r file; do
        filename=$(basename "$file")
        if [[ $filename == *.bin ]]; then
            new_filename="${filename%.bin}-nowifi.bin"
            cp -f "$file" "$FIRMWARE_DIR/$new_filename"
        else
            new_filename="${filename%.*}-nowifi.${filename##*.}"
            cp -f "$file" "$FIRMWARE_DIR/$new_filename"
        fi
    done
    # 重命名 Packages.manifest 为 Packages-nowifi.manifest
    if [ -f "$FIRMWARE_DIR/Packages.manifest" ]; then
        mv "$FIRMWARE_DIR/Packages.manifest" "$FIRMWARE_DIR/Packages-nowifi.manifest"
    fi
else
    find "$TARGET_DIR" -type f \( -name "*.bin" -o -name "*.manifest" -o -name "*efi.img.gz" -o -name "*.itb" -o -name "*.fip" -o -name "*.ubi" -o -name "*rootfs.tar.gz" \) -exec cp -f {} "$FIRMWARE_DIR/" \;
fi

if [[ -d action_build ]]; then
    make clean
fi
