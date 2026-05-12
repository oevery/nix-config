# Linux Nix Config Reference

Linux（非 NixOS）下的 `/etc/nix/nix.conf` 参考配置。

- macOS 若已接入 nix-darwin，优先维护 `modules/darwin/core/system.nix` 中的 `nix.settings`。
- 修改后重启 daemon 或重启系统。

```nix
build-users-group = nixbld
# 启用 nix-command 与 flakes
experimental-features = nix-command flakes
# 可选镜像
substituters = https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org/
# 允许以下用户操作 Nix daemon
trusted-users = root oevery
# 启用沙箱构建
sandbox = true
# 自动优化 store
auto-optimise-store = true
# 保留输出与 derivation
keep-outputs = true
keep-derivations = true
# 构建器可使用二进制缓存
builders-use-substitutes = true
# 允许 flake 中定义的缓存配置生效
accept-flake-config = true
# 网络不稳定时更稳健
connect-timeout = 10
fallback = true
# 自动并发
max-jobs = auto
```
