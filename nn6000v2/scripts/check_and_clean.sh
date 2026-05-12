#!/usr/bin/env bash
# check_and_clean.sh - 检测和清理编译产物
# 用法: ./check_and_clean.sh <package_name> <package_path> [version_source]

set -e

PACKAGE_NAME="$1"
PACKAGE_PATH="$2"
VERSION_SOURCE="${3:-git}"  # git, file, or custom

if [ -z "$PACKAGE_NAME" ] || [ -z "$PACKAGE_PATH" ]; then
    echo "用法: $0 <package_name> <package_path> [version_source]"
    echo "  version_source: git (默认), file, custom"
    exit 1
fi

# 版本记录文件
VERSION_FILE=".pkg_version_${PACKAGE_NAME//[^a-zA-Z0-9]/_}"

# 获取当前版本
get_current_version() {
    local path="$1"
    local source="$2"
    
    case "$source" in
        git)
            if [ -d "$path/.git" ]; then
                cd "$path" && git rev-parse HEAD 2>/dev/null || echo "no-git"
            else
                echo "no-git-dir"
            fi
            ;;
        file)
            if [ -f "$path/Makefile" ]; then
                stat -c %Y "$path/Makefile" 2>/dev/null || echo "no-file"
            else
                echo "no-makefile"
            fi
            ;;
        custom)
            # 可以自定义版本获取逻辑
            echo "custom-version"
            ;;
        *)
            echo "unknown-source"
            ;;
    esac
}

# 清理包的编译产物
clean_package() {
    local pkg_name="$1"
    local staging_dir="${2:-./staging_dir}"
    local build_dir="${3:-./build_dir}"
    
    echo "  清理 '$pkg_name' 的编译产物..."
    
    # 清理 staging_dir 中的 stamp 文件
    STAMP_COUNT=$(find "$staging_dir" -type f -path "*stamp*" -name "*${pkg_name}*" 2>/dev/null | wc -l)
    if [ "$STAMP_COUNT" -gt 0 ]; then
        find "$staging_dir" -type f -path "*stamp*" -name "*${pkg_name}*" -delete 2>/dev/null || true
        echo "    ✓ 删除 $STAMP_COUNT 个 stamp 文件"
    fi
    
    # 清理 build_dir 中的编译目录
    BUILD_COUNT=$(find "$build_dir" -type d -name "*${pkg_name}*" 2>/dev/null | wc -l)
    if [ "$BUILD_COUNT" -gt 0 ]; then
        find "$build_dir" -type d -name "*${pkg_name}*" -exec rm -rf {} + 2>/dev/null || true
        echo "    ✓ 删除 $BUILD_COUNT 个 build 目录"
    fi
    
}

# 主逻辑
main() {
    # 检查是否有缓存（staging_dir 是否存在）
    if [ ! -d "./staging_dir" ]; then
        # 没有缓存，首次编译，只记录版本不清理
        CURRENT_VERSION=$(get_current_version "$PACKAGE_PATH" "$VERSION_SOURCE")
        if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "no-git-dir" ] && [ "$CURRENT_VERSION" != "no-makefile" ]; then
            echo "=== 首次编译，记录版本: $PACKAGE_NAME (${CURRENT_VERSION:0:8}) ==="
            echo "$CURRENT_VERSION" > "$VERSION_FILE"
        fi
        return 0
    fi
    
    echo "=== 检测包更新: $PACKAGE_NAME ==="
    
    # 检查包路径是否存在
    if [ ! -d "$PACKAGE_PATH" ]; then
        echo "  ⚠️ 包路径不存在: $PACKAGE_PATH"
        return 0
    fi
    
    # 获取当前版本
    CURRENT_VERSION=$(get_current_version "$PACKAGE_PATH" "$VERSION_SOURCE")
    
    if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" = "no-git-dir" ] || [ "$CURRENT_VERSION" = "no-makefile" ]; then
        echo "  ⚠️ 无法获取版本信息 ($CURRENT_VERSION)"
        # 首次运行，记录版本但不清理
        echo "$CURRENT_VERSION" > "$VERSION_FILE"
        return 0
    fi
    
    # 检查是否有上次记录的版本
    if [ -f "$VERSION_FILE" ]; then
        LAST_VERSION=$(cat "$VERSION_FILE")
        
        if [ "$LAST_VERSION" != "$CURRENT_VERSION" ]; then
            echo "  🔄 检测到更新!"
            echo "    上次版本: ${LAST_VERSION:0:8}"
            echo "    当前版本: ${CURRENT_VERSION:0:8}"
            
            # 清理编译产物
            clean_package "$PACKAGE_NAME"
            
            echo "  ✓ 清理完成，将重新编译"
        else
            echo "  ✅ 无更新 (${CURRENT_VERSION:0:8})"
        fi
    else
        echo "  📝 首次记录版本: ${CURRENT_VERSION:0:8}"
    fi
    
    # 更新版本记录
    echo "$CURRENT_VERSION" > "$VERSION_FILE"
}

main