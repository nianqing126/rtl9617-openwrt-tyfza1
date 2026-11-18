#!/bin/sh
# 统一固件的型号标识，使其与设备树 board_name 一致。
#
# 背景：上游 include/image.mk 的 Device/Init 里有
#   SUPPORTED_DEVICES := $(subst _,$(comma),$(1))
# 它把设备 profile 名 tianyi_tyfza1_2p5g 的下划线全部换成逗号，得到
#   tianyi,tyfza1,2p5g
# 而设备树 compatible / board_name 是
#   tianyi,tyfza1-2p5g   （2p5g 前是连字符）
# 两者不一致，导致 sysupgrade 的 fwtool_check_image 型号检查必然失败，
# 只能用 -F 强刷，且看不到明确的 "sysupgrade successful" 反馈。
#
# 本脚本在设备定义里显式设置 SUPPORTED_DEVICES，覆盖上游默认值，使
# 镜像 metadata 自报的型号与 board_name 完全一致，sysupgrade 无需 -F。
set -eu

TREE=${1:?Usage: fix_supported_devices.sh <openwrt-tree>}
MK="$TREE/target/linux/rtl9617c/image/Makefile"

[ -f "$MK" ] || { echo "找不到 $MK" >&2; exit 1; }

# 幂等：若已修正则直接返回，重复运行不会重复插入。
if grep -q 'SUPPORTED_DEVICES := tianyi,tyfza1-2p5g' "$MK"; then
    echo "SUPPORTED_DEVICES 已修正，跳过"
    exit 0
fi

awk '
    /^define Device\/tianyi_tyfza1_2p5g$/ { in2=1; in4=0 }
    /^define Device\/tianyi_tyfza1_4ge$/  { in2=0; in4=1 }
    /^endef$/                             { in2=0; in4=0 }
    { print }
    in2 && /DEVICE_VARIANT/ { print "  SUPPORTED_DEVICES := tianyi,tyfza1-2p5g" }
    in4 && /DEVICE_VARIANT/ { print "  SUPPORTED_DEVICES := tianyi,tyfza1-4ge" }
' "$MK" > "$MK.tmp"

mv "$MK.tmp" "$MK"

# 自检：两个设备都必须有正确的值，否则判定失败。
grep -q 'SUPPORTED_DEVICES := tianyi,tyfza1-2p5g' "$MK" || { echo "2p5g 型号注入失败" >&2; exit 1; }
grep -q 'SUPPORTED_DEVICES := tianyi,tyfza1-4ge' "$MK"  || { echo "4ge 型号注入失败" >&2; exit 1; }
echo "SUPPORTED_DEVICES 已统一："
grep -n 'SUPPORTED_DEVICES' "$MK"
