#!/bin/bash

# Docker 版本和配置管理
# 更新 Docker 组件版本和配置 nftables 防火墙

BUILD_DIR="${1:-.}"

# 版本配置
DOCKER_RUNC_VERSION="v1.3.5"
DOCKER_CONTAINERD_VERSION="v1.7.30"
DOCKER_DOCKER_VERSION="v29.3.1"
DOCKER_DOCKERD_VERSION="${DOCKER_DOCKER_VERSION}"
DOCKER_STORAGE_DRIVER="vfs"

echo "==================================="
echo "Docker Stack Update"
echo "==================================="

# 更新组件版本
update_component() {
    local component=$1
    local version=$2
    local version_clean=$(echo $version | sed 's/v//')
    
    local makefile=$(find $BUILD_DIR/package/feeds/packages/$component $BUILD_DIR/feeds/packages/*/$component -name "Makefile" 2>/dev/null | head -1)
    
    if [ -n "$makefile" ]; then
        # 更新版本
        sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$version_clean/" $makefile
        
        # 计算并更新 HASH
        local pkg_source_url=$(awk -F"=" '/^PKG_SOURCE_URL:=/ {print $NF}' $makefile | grep -oE "[-_:/\$\(\)\{\}\?\.a-zA-Z0-9]{1,}")
        local pkg_source=$(awk -F"=" '/^PKG_SOURCE:=/ {print $NF}' $makefile | grep -oE "[-_:/\$\(\)\?\.a-zA-Z0-9]{1,}")
        local pkg_name=$(awk -F"=" '/^PKG_NAME:=/ {print $NF}' $makefile | grep -oE "[-_:/\$\(\)\?\.a-zA-Z0-9]{1,}")
        
        # 替换变量
        pkg_source_url=$(echo "$pkg_source_url" | sed "s/\$(PKG_VERSION)/$version_clean/g; s/\${PKG_VERSION}/$version_clean/g; s/\$(PKG_NAME)/$pkg_name/g")
        pkg_source=$(echo "$pkg_source" | sed "s/\$(PKG_VERSION)/$version_clean/g; s/\$(PKG_NAME)/$pkg_name/g")
        
        # 下载并计算 HASH
        if [ -n "$pkg_source_url" ] && [ -n "$pkg_source" ]; then
            local pkg_hash=$(curl -fsSL "${pkg_source_url}${pkg_source}" 2>/dev/null | sha256sum | cut -b -64)
            if [ -n "$pkg_hash" ]; then
                sed -i "s/PKG_HASH:=.*/PKG_HASH:=$pkg_hash/" $makefile
                echo "✓ $component updated to $version (HASH: ${pkg_hash:0:16}...)"
            else
                echo "⚠ $component version updated, but HASH calculation failed"
            fi
        else
            echo "✓ $component updated to $version"
        fi
    else
        echo "✗ $component Makefile not found"
    fi
}

# 更新所有组件
update_component "runc" "$DOCKER_RUNC_VERSION"
update_component "containerd" "$DOCKER_CONTAINERD_VERSION"
update_component "docker" "$DOCKER_DOCKER_VERSION"
update_component "dockerd" "$DOCKER_DOCKERD_VERSION"

# 配置 dockerd nftables 防火墙
dockerd_config=$(find $BUILD_DIR/package/feeds/packages/dockerd $BUILD_DIR/feeds/packages/*/dockerd -path "*/files/etc/config/dockerd" 2>/dev/null | head -1)

if [ -n "$dockerd_config" ]; then
    # 设置防火墙后端为 nftables
    if grep -q "firewall_backend" $dockerd_config; then
        sed -i "s/option firewall_backend '.*/option firewall_backend 'nftables'/" $dockerd_config
    else
        echo -e "\n\toption firewall_backend 'nftables'" >> $dockerd_config
    fi
    
    # 设置存储驱动
    if grep -q "storage_driver" $dockerd_config; then
        sed -i "s/option storage_driver '.*/option storage_driver '$DOCKER_STORAGE_DRIVER'/" $dockerd_config
    else
        echo -e "\toption storage_driver '$DOCKER_STORAGE_DRIVER'" >> $dockerd_config
    fi
    
    echo "✓ dockerd config updated (nftables, $DOCKER_STORAGE_DRIVER)"
else
    echo "✗ dockerd config not found"
fi

# 配置 sysctl 网络转发
sysctl_conf=$(find $BUILD_DIR/package/feeds/packages/dockerd $BUILD_DIR/feeds/packages/*/dockerd -path "*/files/etc/sysctl.d/*.conf" 2>/dev/null | head -1)

if [ -n "$sysctl_conf" ]; then
    # 启用 IP 转发
    if ! grep -q "net.ipv4.ip_forward=1" $sysctl_conf; then
        echo "net.ipv4.ip_forward=1" >> $sysctl_conf
    fi
    if ! grep -q "net.ipv6.conf.all.forwarding=1" $sysctl_conf; then
        echo "net.ipv6.conf.all.forwarding=1" >> $sysctl_conf
    fi
    echo "✓ sysctl forwarding enabled"
fi

echo "==================================="
echo "Docker Stack Update Complete"
echo "==================================="
