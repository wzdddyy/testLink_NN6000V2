#!/usr/bin/env bash
# Determine nn6000v2 path
if [ -d "nn6000v2" ]; then
    NN6000V2_PATH="nn6000v2"
elif [ -d "../nn6000v2" ]; then
    NN6000V2_PATH="../nn6000v2"
else
    # Fallback to parent directory of script directory
    NN6000V2_PATH=$(dirname "$(dirname "$0")")
fi

BASE_PATH=$(cd "$NN6000V2_PATH" && pwd)

Dev=$1

# 使用环境变量
REPO_URL="${REPO_URL}"
REPO_BRANCH="${REPO_BRANCH:-main}"
BUILD_DIR="${BUILD_DIR:-action_build}"


if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$BASE_PATH/../$BUILD_DIR"
fi

echo $REPO_URL $REPO_BRANCH $BUILD_DIR
echo "$REPO_URL/$REPO_BRANCH" >"$BASE_PATH/../repo_flag"
git clone --depth 1 -b $REPO_BRANCH $REPO_URL $BUILD_DIR

# GitHub Action 移除国内下载源
PROJECT_MIRRORS_FILE="$BUILD_DIR/scripts/projectsmirrors.json"
if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi
