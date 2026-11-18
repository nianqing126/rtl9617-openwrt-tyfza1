#!/bin/sh
# 拉取源码并检出 main 分支固定提交，避免默认分支 refactor 不含 TYFZA1 设备。
set -eu

PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TREE=${1:-$PROJECT/openwrt}

SRC_URL=${SRC_URL:-https://github.com/lyq1996/rtl9617c-openwrt.git}
# git ls-remote 确认的 main 分支 HEAD，来源为 2026-10-29 的 tmp 提交。
SRC_COMMIT=${SRC_COMMIT:-cea9938fc81fd7fe2b7a9ddd71f2d0e4ed7895bf}

if [ -d "$TREE/.git" ]; then
    echo "源码树已存在：$TREE"
else
    mkdir -p "$TREE"
    git init "$TREE"
fi

cd "$TREE"
git remote add origin "$SRC_URL" 2>/dev/null || git remote set-url origin "$SRC_URL"
git fetch --depth 1 origin "$SRC_COMMIT"
git checkout --detach FETCH_HEAD
git rev-parse HEAD
