# Linux Nix Config Reference

本页用于 Linux（非 NixOS）场景下的 `/etc/nix/nix.conf` 参考配置。

说明：

- macOS 若已接入 nix-darwin，应优先在 `modules/darwin/core/system.nix` 中维护 `nix.settings`。
- Linux 上可把以下内容写入 `/etc/nix/nix.conf`，再重启 daemon 或重启系统。

```nix
build-users-group = nixbld
# 启用 nix-command 与 flakes
experimental-features = nix-command flakes
# 中国大陆网络环境可使用清华镜像
substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
# 允许以下用户操作 Nix daemon
trusted-users = root oevery
# 启用沙箱构建，提高可复现性
sandbox = true
# 自动去重 store 中重复文件
auto-optimise-store = true
# 保留输出与 derivation，便于调试和复用
keep-outputs = true
keep-derivations = true
# 构建器可使用二进制缓存
builders-use-substitutes = true
# 允许 flake 中定义的缓存配置生效（常见于现代 flake 项目）
accept-flake-config = true
# 网络不稳定时更稳健
connect-timeout = 10
fallback = true
# 提升下载并发与体验（按机器性能可调整）
max-jobs = auto
```
