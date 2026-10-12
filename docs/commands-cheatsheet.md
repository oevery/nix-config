# Commands Cheat Sheet

## Core

```bash
# 更新依赖
nix flake update --flake ~/.config/home-manager

# 当前 host 求值检查（固定仓库路径，可在任意目录运行）
hc

# 全部平台求值检查（不构建、不修改 lock 文件）
nix flake check --all-systems --no-build --no-write-lock-file ~/.config/home-manager

# 当前平台构建检查
nix flake check --no-write-lock-file ~/.config/home-manager
```

## Linux (Home Manager)

```bash
# 推荐
hms

# 原生命令
home-manager switch --flake ~/.config/home-manager#<homeConfigurationName>
```

## macOS (nix-darwin)

macOS 的 Home Manager 由 nix-darwin 统一激活，不提供独立的 `hms` 命令。

```bash
# 推荐
drs

# 调试
drst

# 更新并验证 Homebrew 最新稳定版（不激活系统）
brewup

# 原生命令
sudo nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#<darwinName>
```

## Quick Eval

```bash
# Home Manager 输出求值
nix eval --raw path:$PWD#homeConfigurations.<homeConfigurationName>.activationPackage.drvPath

# Darwin 输出求值
nix eval --raw path:$PWD#darwinConfigurations.oevery-mac.config.system.build.toplevel.drvPath
```

## Garbage Collection

自动 GC 每周清理 30 天前的旧代。日常无需手动删除全部旧代。

```bash
# 主动放弃当前用户全部旧代的回滚能力时使用
nix-gc-delete-all-old-generations
```

Nix 保留 derivation 用于追溯，但不额外保留仅构建时需要的输出。Linux 的 daemon 配置参考 [linux-nix-conf.md](linux-nix-conf.md)。
