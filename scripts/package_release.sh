#!/bin/sh
# 汇总两个变体的产物，便于 artifact/release 使用。
set -eu

PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-$PROJECT/artifacts/release}
mkdir -p "$OUT"

for variant in 2p5g 4ge; do
    src="$PROJECT/artifacts/$variant"
    [ -d "$src" ] || continue
    dst="$OUT/$variant"
    mkdir -p "$dst"
    cp "$src"/* "$dst/"
done

: > "$OUT/SHA256SUMS.all"
find "$OUT" -type f ! -name 'SHA256SUMS*' -print0 | sort -z | xargs -0 sha256sum >> "$OUT/SHA256SUMS.all"
cp "$PROJECT/README.md" "$OUT/README.txt"
ls -lh "$OUT"
