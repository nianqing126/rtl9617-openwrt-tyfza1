# TYFZA1 云编译工程

面向 [lyq1996/rtl9617c-openwrt](https://github.com/lyq1996/rtl9617c-openwrt) 的 GitHub Actions 云编译工程，输出天翼 TYFZA1（Realtek RTL9617C）的 OpenWrt 固件。

## 源码结论

该仓库的 `main` 分支已经包含完整的 RTL9617C OpenWrt 目标：

- `target/linux/rtl9617c`：内核 6.18、设备树、PON/无线/网络驱动、PE 固件源码；
- `target/linux/rtl9617c/image/Makefile`：定义 `tianyi_tyfza1_2p5g` 与 `tianyi_tyfza1_4ge` 两个设备；
- `package/tyfza1-pon-control`、`package/luci-app-tyfza1-pon`：PON 管理与 LuCI 页面；
- 设备启动时从原厂 `factory` UBI 卷读取 MAC、PON SN、光模块与 Wi-Fi 校准数据，因此**不需要上传私有校准文件**。

注意：仓库默认分支 `refactor` 已把设备改为 `youhua_pt1500_h10_2p5g`，不再导出 TYFZA1 设备。此工程固定使用 `main` 分支，避免误编译成其它机型。

## 使用方法

1. 把本目录整体推送到你自己的 GitHub 仓库。
2. 进入 **Actions → Build TYFZA1 firmware → Run workflow**。
3. 运行结束后，从 **Artifacts → tyfza1-firmware-\<run_id\>** 下载固件；如填写 `release_tag` 并推送对应 tag，也会发布到 Releases。

工作流会并行编译两个变体：

| 变体 | 设备配置 | 主要产物 |
| --- | --- | --- |
| 2.5G 版 | `tianyi_tyfza1_2p5g` | `openwrt-rtl9617c-generic-tianyi_tyfza1_2p5g-squashfs-sysupgrade.itb` |
| 全千兆版 | `tianyi_tyfza1_4ge` | `openwrt-rtl9617c-generic-tianyi_tyfza1_4ge-squashfs-sysupgrade.itb` |

固件从源码直接产出，未做二次修改；`SHA256SUMS` 与构建配置也会一并上传。

## 云编译做了哪些额外处理

源码不能直接 `feeds install -a && make`，还需要以下步骤，已写入工作流：

1. 安装 Clang/LLVM 18、lld、Rust 1.96.1 的 `aarch64-unknown-linux-musl` 目标；
2. 先在源码树内执行 `make -C target/linux/rtl9617c/pe`，生成无线 PE 固件头文件 `pe-tx-code.h`；
3. 拉取 Argon 主题固定提交 `539e3e1db56b2348c3655615540e45638b797c73`，并链接到 `package/luci-theme-argon`；
4. 将源码自带的三个 LuCI feed 补丁应用到 `feeds/luci`，否则 PON 状态页、资源版本号和功率标签不完整；
5. 分别用 `configs/tyfza1-2p5g.config` 与 `configs/tyfza1-4ge.config` 生成配置，校验目标设备和关键包后编译。

## 刷机提醒

- 本工程输出的是 `sysupgrade.itb`（FIT 格式），供该项目配套的原生 U-Boot 使用；它不是 `LeoooChen/PonWRT-TYFZA1` 项目中的 `sysupgrade.bin`（UBI sysupgrade tar），两者不可混刷。
- 刷机前请确认设备型号、U-Boot 版本与固件格式匹配，并备份原厂固件/分区。
- PON 注册与各运营商 OLT 的兼容性需要实机验证。

## 目录说明

```text
.github/workflows/build.yml   云编译与发布流程
configs/tyfza1-2p5g.config    2.5G 版配置种子
configs/tyfza1-4ge.config     全千兆版配置种子
scripts/prepare_openwrt.sh    拉取并锁定源码
scripts/prepare_feeds.sh      准备 feeds、Argon 主题和 LuCI 补丁
scripts/build_one.sh          单变体配置校验、编译与产物收集
scripts/package_release.sh    汇总产物与生成 SHA256SUMS
```
