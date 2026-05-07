#!/usr/bin/env bash
# Module: General Preparation
clone_repo() {
    if [[ ! -d $BUILD_DIR ]]; then
        echo "克隆仓库：$REPO_URL 分支：$REPO_BRANCH"
        if ! git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR; then
            echo "错误：克隆仓库 $REPO_URL 失败" >&2
            exit 1
        fi
    fi
}

apply_patches() {
    # 如果没有设置 BASE_PATH，使用脚本所在目录
    if [[ -z "$BASE_PATH" ]]; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
    
    local PATCHES_DIR="$BASE_PATH/patches"
    
    if [[ ! -d "$PATCHES_DIR" ]]; then
        echo "补丁目录不存在：$PATCHES_DIR"
        return 0
    fi
    
    local patch_count=$(ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null | wc -l)
    if [[ $patch_count -eq 0 ]]; then
        echo "没有找到补丁文件"
        return 0
    fi
    
    echo "应用补丁文件 ($patch_count 个)..."
    cd "$BUILD_DIR"
    
    for patch in "$PATCHES_DIR"/*.patch; do
        if [[ -f "$patch" ]]; then
            local patch_name=$(basename $patch)
            echo "  应用：$patch_name"
            
            # 检查补丁类型
            if head -5 "$patch" | grep -q "^--- a/"; then
                # 标准 git 格式补丁，使用 -p1
                if ! patch -p1 --dry-run < "$patch" >/dev/null 2>&1; then
                    echo "    警告：补丁 $patch_name 应用失败（可能是源码已更新或路径不匹配），跳过..."
                else
                    patch -p1 < "$patch" 2>/dev/null
                fi
            else
                # 其他格式补丁，尝试自动检测
                if ! patch -p1 --dry-run < "$patch" >/dev/null 2>&1; then
                    if ! patch -p0 --dry-run < "$patch" >/dev/null 2>&1; then
                        echo "    警告：补丁 $patch_name 无法应用，跳过..."
                    else
                        patch -p0 < "$patch" 2>/dev/null
                    fi
                else
                    patch -p1 < "$patch" 2>/dev/null
                fi
            fi
        fi
    done
    
    echo "补丁应用完成"
}

clean_up() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Build directory $BUILD_DIR does not exist"
        return
    fi
    cd "$BUILD_DIR"
    if [[ -f ".config" ]]; then
        \rm -f ".config"
    fi
    if [[ -d "tmp" ]]; then
        \rm -rf "tmp"
    fi
    if [[ -d "logs" ]]; then
        \rm -rf "logs/*"
    fi
    if [[ -d "feeds" ]]; then
        ./scripts/feeds clean
    fi
    mkdir -p "tmp"
    echo "1" >"tmp/.build"
}

reset_feeds_conf() {
    git reset --hard origin/$REPO_BRANCH
    git clean -f -d
    git pull
    if [[ $COMMIT_HASH != "none" ]]; then
        git checkout $COMMIT_HASH
    fi
}
