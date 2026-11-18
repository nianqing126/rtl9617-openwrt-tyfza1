#!/bin/sh
# 编译单个 TYFZA1 变体。
set -eu

PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TREE=${1:?Usage: build_one.sh <openwrt-tree> <variant>}
VARIANT=${2:?Usage: build_one.sh <openwrt-tree> <variant>}
OUT=${3:-$PROJECT/artifacts/$VARIANT}

case "$VARIANT" in
    2p5g)
        DEVICE=tianyi_tyfza1_2p5g
        CONFIG=$PROJECT/configs/tyfza1-2p5g.config
        ;;
    4ge)
        DEVICE=tianyi_tyfza1_4ge
        CONFIG=$PROJECT/configs/tyfza1-4ge.config
        ;;
    *)
        echo "未知变体：$VARIANT" >&2
        exit 1
        ;;
esac

mkdir -p "$OUT"
cd "$TREE"

# 自检：固件 metadata 的型号必须与设备树 board_name 一致，
# 否则 sysupgrade 型号检查会失败、被迫用 -F 强刷。
case "$VARIANT" in
    2p5g) EXPECTED_DEV="tianyi,tyfza1-2p5g" ;;
    4ge)  EXPECTED_DEV="tianyi,tyfza1-4ge" ;;
esac
grep -q "SUPPORTED_DEVICES := ${EXPECTED_DEV}" \
    "$TREE/target/linux/rtl9617c/image/Makefile" || {
    echo "型号未统一：期望 SUPPORTED_DEVICES := ${EXPECTED_DEV}，请检查 fix_supported_devices.sh" >&2
    exit 1
}

cp "$CONFIG" .config
make defconfig

# 防止配置被上游默认值改写后仍继续编译出错误目标。
grep -qx 'CONFIG_TARGET_BOARD="rtl9617c"' .config
grep -qx 'CONFIG_TARGET_SUBTARGET="generic"' .config
grep -qx "CONFIG_TARGET_rtl9617c_generic_DEVICE_${DEVICE}=y" .config
for pkg in tyfza1-pon-control luci-app-tyfza1-pon kmod-rtl-ax-ap luci-theme-argon; do
    grep -qx "CONFIG_PACKAGE_${pkg}=y" .config || {
        echo "关键包 $pkg 未被配置选中" >&2
        exit 1
    }
done

JOBS=${JOBS:-$(nproc)}
make -j"$JOBS" download
make -j"$JOBS" 2>&1 | tee "$OUT/build.log"

BIN="$TREE/bin/targets/rtl9617c/generic"
found=0
for img in "$BIN"/*"$DEVICE"*; do
    [ -f "$img" ] || continue
    cp "$img" "$OUT/"
    found=1
done
[ "$found" -eq 1 ] || {
    echo "未找到 $DEVICE 的镜像，检查 bin/targets/rtl9617c/generic" >&2
    exit 1
}

cp .config "$OUT/config.buildinfo"
cp "$TREE/target/linux/rtl9617c/files-6.18/drivers/net/wireless/realtek/rtl_ax_ap/pe-tx-code.h" "$OUT/"
(cd "$OUT" && sha256sum * > SHA256SUMS)
ls -lh "$OUT"
