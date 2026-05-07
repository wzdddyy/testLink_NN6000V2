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
            echo "  应用：$(basename $patch)"
            if ! patch -p1 < "$patch"; then
                echo "警告：补丁 $(basename $patch) 应用失败，继续下一个..."
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
