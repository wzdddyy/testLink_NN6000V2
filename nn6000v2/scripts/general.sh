#!/usr/bin/env bash
# Module: General Preparation
clone_repo() {
    if [[ ! -d $BUILD_DIR ]]; then
        echo "克隆仓库: $REPO_URL 分支: $REPO_BRANCH"
        if ! git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR; then
            echo "错误：克隆仓库 $REPO_URL 失败" >&2
            exit 1
        fi
    fi
}

clean_up() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Build directory $BUILD_DIR does not exist"
        return
    fi
    (cd "$BUILD_DIR" && {
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
    })
}

reset_feeds_conf() {
    cd "$BUILD_DIR"
    
    # 临时移动需要保留的缓存目录，避免被 git clean 删除
    local preserve_dirs=("staging_dir" ".ccache" "dl" "build_dir")
    local backup_root="../.git_clean_backup_$$"
    
    for dir in "${preserve_dirs[@]}"; do
        if [ -d "$dir" ]; then
            mkdir -p "$backup_root"
            mv "$dir" "$backup_root/"
            echo "[INFO] 备份缓存目录: $dir"
        fi
    done
    
    # 安全地清理 Git 未跟踪文件
    git reset --hard origin/$REPO_BRANCH
    git clean -f -d
    git pull
    
    if [[ $COMMIT_HASH != "none" ]]; then
        git checkout $COMMIT_HASH
    fi
    
    # 恢复缓存目录
    for dir in "${preserve_dirs[@]}"; do
        if [ -d "$backup_root/$dir" ]; then
            mv "$backup_root/$dir" "./"
            echo "[INFO] 恢复缓存目录: $dir"
        fi
    done
    
    # 清理备份目录
    [ -d "$backup_root" ] && rm -rf "$backup_root"
    
    cd - > /dev/null
}
