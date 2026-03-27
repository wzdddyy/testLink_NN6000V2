#!/bin/bash
# 应用 12M 设备定义的 patches

set -e

echo "=== 应用 12M 设备定义 patches ==="

# 检查 patches 目录是否存在
if [ ! -d "patches" ]; then
    echo "错误：patches 目录不存在！"
    exit 1
fi

# 检查源码目录是否存在
if [ ! -d "target/linux/qualcommax" ]; then
    echo "错误：target/linux/qualcommax 目录不存在！请确保已克隆源码。"
    exit 1
fi

# 创建 dts 目录（如果不存在）
mkdir -p target/linux/qualcommax/dts

# 复制 DTS 文件
echo "复制 DTS 文件..."
if [ -f "patches/ipq6000-nn6000-v2-12m.dts" ]; then
    cp patches/ipq6000-nn6000-v2-12m.dts target/linux/qualcommax/dts/
    echo "✓ DTS 文件已复制到 target/linux/qualcommax/dts/"
else
    echo "✗ DTS 文件不存在"
    exit 1
fi

# 应用 Makefile patch
echo "应用 Makefile patch..."
if [ -f "patches/ipq60xx-12m-device.patch" ]; then
    cd target/linux/qualcommax/
    patch -p1 < ../../../patches/ipq60xx-12m-device.patch
    echo "✓ Makefile patch 已应用"
else
    echo "✗ Makefile patch 不存在"
    exit 1
fi

echo "=== 12M 设备定义应用完成 ==="
