#!/usr/bin/env bash

# Determine wrt_core path
if [ -d "wrt_core" ]; then
    WRT_CORE_PATH="wrt_core"
elif [ -d "../wrt_core" ]; then
    WRT_CORE_PATH="../wrt_core"
else
    # Fallback to script directory if wrt_core is current dir or relative
    WRT_CORE_PATH=$(dirname "$0")
fi

BASE_PATH=$(cd "$WRT_CORE_PATH" && pwd)

Dev=$1

INI_FILE="$BASE_PATH/compilecfg/$Dev.ini"

if [[ ! -f $INI_FILE ]]; then
    echo "INI file not found: $INI_FILE"
    exit 1
fi

read_ini_by_key() {
    local key=$1
    awk -F"=" -v key="$key" '$1 == key {print $2}' "$INI_FILE"
}

REPO_URL=$(read_ini_by_key "REPO_URL")
REPO_BRANCH=$(read_ini_by_key "REPO_BRANCH")
REPO_BRANCH=${REPO_BRANCH:-main}
# GitHub Actions usually runs in root of repo, so build dir should be relative to repo root
# We need to construct absolute path or ensure context is correct.
# Assuming this script is run from repo root or wrt_core.
# Let's use relative path "action_build" next to wrt_core if possible or just use what works.
# Original script used BASE_PATH/action_build.
BUILD_DIR="$BASE_PATH/../action_build"

echo $REPO_URL $REPO_BRANCH
# Write flag one level up from wrt_core (repo root usually)
echo "$REPO_URL/$REPO_BRANCH" >"$BASE_PATH/../repo_flag"
git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR

# GitHub Action 移除国内下载源
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"

if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi

# 如果是 12M 设备，克隆完成后立即复制 patches
if [[ "$Dev" == *"12m"* ]] || [[ "$Dev" == *"12M"* ]]; then
    echo "检测到 12M 设备配置，复制 12M patches..."
    
    # 检查源码目录是否存在
    if [ ! -d "$BUILD_DIR/target/linux/qualcommax" ]; then
        echo "错误：target/linux/qualcommax 目录不存在！"
        exit 1
    fi
    
    # 创建 dts 目录
    mkdir -p "$BUILD_DIR/target/linux/qualcommax/dts"
    
    # 复制 DTS 文件到源码目录
    if [ -f "$BASE_PATH/../patches/ipq6000-nn6000-v2-12m.dts" ]; then
        cp "$BASE_PATH/../patches/ipq6000-nn6000-v2-12m.dts" "$BUILD_DIR/target/linux/qualcommax/dts/"
        echo "✓ DTS 文件已复制到 $BUILD_DIR/target/linux/qualcommax/dts/"
        # 验证文件是否存在
        ls -lh "$BUILD_DIR/target/linux/qualcommax/dts/"
    else
        echo "✗ DTS 文件不存在"
        exit 1
    fi
    
    # 应用 Makefile patch
    if [ -f "$BASE_PATH/../patches/ipq60xx-12m-device.patch" ]; then
        cd "$BUILD_DIR/target/linux/qualcommax/"
        patch -p1 < ../../../../patches/ipq60xx-12m-device.patch
        echo "✓ Makefile patch 已应用"
    else
        echo "✗ Makefile patch 不存在"
        exit 1
    fi
    
    echo "=== 12M 设备定义 patches 应用完成 ==="
fi
