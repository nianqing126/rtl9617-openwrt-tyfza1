#!/bin/sh
# 准备 feeds、Argon 主题和 LuCI 补丁。
set -eu

PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TREE=${1:-$PROJECT/openwrt}
cd "$TREE"

ARGON_URL=${ARGON_URL:-https://github.com/jerrykuku/luci-theme-argon.git}
ARGON_COMMIT=${ARGON_COMMIT:-539e3e1db56b2348c3655615540e45638b797c73}

# 1. 标准 feeds。
./scripts/feeds update -a

# 2. Argon 3 是单包仓库，需要放到 feeds/ 并链接到 package/。
ARGON="$TREE/feeds/luci-theme-argon"
mkdir -p "$TREE/feeds"
if [ ! -d "$ARGON/.git" ]; then
    git init "$ARGON"
fi
if ! git -C "$ARGON" diff --quiet || ! git -C "$ARGON" diff --cached --quiet; then
    echo "Argon  checkout 存在本地改动，拒绝覆盖" >&2
    exit 1
fi
if [ "$(git -C "$ARGON" rev-parse --verify HEAD 2>/dev/null || true)" != "$ARGON_COMMIT" ]; then
    git -C "$ARGON" fetch --depth 1 "$ARGON_URL" "$ARGON_COMMIT"
    git -C "$ARGON" checkout --detach FETCH_HEAD
fi
if [ -e "$TREE/package/luci-theme-argon" ] && [ ! -L "$TREE/package/luci-theme-argon" ]; then
    echo "package/luci-theme-argon 已存在且不是符号链接" >&2
    exit 1
fi
ln -sfn "$ARGON" "$TREE/package/luci-theme-argon"

# 3. 应用源码自带的 LuCI feed 补丁；若已应用则跳过。
for patch in "$TREE"/package/luci-app-tyfza1-pon/feed-patches/*.patch; do
    [ -e "$patch" ] || continue
    name=$(basename "$patch")
    if git -C "$TREE/feeds/luci" apply --reverse --check "$patch" 2>/dev/null; then
        echo "LuCI 补丁已应用，跳过：$name"
    else
        git -C "$TREE/feeds/luci" apply --check "$patch"
        git -C "$TREE/feeds/luci" apply "$patch"
        echo "已应用 LuCI 补丁：$name"
    fi
done

# 4. 安装全部 feed 包。
./scripts/feeds install -a

# 5. 生成无线 PE 固件头文件，否则内核编译会报 pe-tx-code.h missing。
make -C "$TREE/target/linux/rtl9617c/pe"
test -s "$TREE/target/linux/rtl9617c/files-6.18/drivers/net/wireless/realtek/rtl_ax_ap/pe-tx-code.h"
