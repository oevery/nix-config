# Linux Nix Config Reference

这是非 NixOS Linux 多用户安装的 **daemon** 配置示例，不是 `hms` 自动写入的文件。按需合并到 `/etc/nix/nix.conf`，保留安装器已有设置；修改后重启 `nix-daemon` 或系统。用户侧的 registry 和定时 GC 由 [Linux Home Manager 模块](../modules/linux/core/nix.nix)管理。

```nix
build-users-group = nixbld
# 启用 nix-command 与 flakes
experimental-features = nix-command flakes
# 可选镜像
substituters = https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org/
# 普通用户可连接 daemon；额外信任权限仅保留给 root
allowed-users = *
trusted-users = root
# 启用沙箱构建
sandbox = true
# 自动优化 store
auto-optimise-store = true
# 保留 derivation 用于追溯，不额外保留仅构建时需要的输出
keep-outputs = false
keep-derivations = true
# 构建器可使用二进制缓存
builders-use-substitutes = true
# 保留默认值，不自动接受 flake 提议的配置
accept-flake-config = false
# 网络不稳定时更稳健
connect-timeout = 10
fallback = true
# 自动并发
max-jobs = auto
```
