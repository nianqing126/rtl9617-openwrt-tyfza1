#!/bin/sh
# 汇总两个变体的产物：扁平化并确保文件名全局唯一。
# 发布环节要求 asset 名唯一；两个变体目录下原本都有同名的
# SHA256SUMS / config.buildinfo / pe-tx-code.h，直接递归上传会触发
# GitHub Actions 更新 asset 元数据时的 404。
set -eu

PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-$PROJECT/artifacts/release}
mkdir -p "$OUT"
# 清理旧产物，避免重复运行时残留文件被一起发布
find "$OUT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

for variant in 2p5g 4ge; do
    src="$PROJECT/artifacts/$variant"
    [ -d "$src" ] || continue
    for f in "$src"/*; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
            # 这些是构建元信息/日志，统一在根目录生成或无需发布
            SHA256SUMS|SHA256SUMS.*|build.log) continue ;;
        esac
        case "$name" in
            # 固件镜像名本身已含变体型号，天然唯一
            openwrt-*) dest="$OUT/$name" ;;
            # 其余文件加变体前缀，避免跨变体同名
            *)         dest="$OUT/${variant}-${name}" ;;
        esac
        cp "$f" "$dest"
    done
done

# 统一生成一份校验和（临时文件放在 OUT 之外，避免被计入自身）
SUMS_TMP=$(mktemp)
(cd "$OUT" && for f in *; do [ -f "$f" ] || continue; sha256sum "$f"; done > "$SUMS_TMP")
mv "$SUMS_TMP" "$OUT/SHA256SUMS.all"
cp "$PROJECT/README.md" "$OUT/README.txt"

# 自检：文件名必须全局唯一（git 分支去重后不应有重复 basename）
dups=$(cd "$OUT" && ls -1 | sort | uniq -d)
[ -z "$dups" ] || {
    echo "发布目录存在重复文件名：$dups" >&2
    exit 1
}
ls -lh "$OUT"
