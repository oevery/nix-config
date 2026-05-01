# Commands Cheat Sheet

## Core

```bash
# 更新依赖
nix flake update --flake ~/.config/home-manager

# 仅评估检查（不切换）
SYS="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix eval --json ".#checks.${SYS}"

# 标准检查
nix flake check
```

## Linux (Home Manager)

```bash
# 走 alias（推荐）
hms

# 原生命令
home-manager switch --flake ~/.config/home-manager#$(whoami)@$(hostname)
```

## macOS (nix-darwin)

```bash
# 走 alias（推荐）
drs

# 调试版 alias
drst

# 原生命令（需要 sudo）
sudo nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#oevery-mac
```

## Quick Eval

```bash
# Home Manager 输出求值
nix eval --raw path:$PWD#homeConfigurations."$(whoami)@$(hostname)".activationPackage.drvPath

# Darwin 输出求值
nix eval --raw path:$PWD#darwinConfigurations.oevery-mac.config.system.build.toplevel.drvPath
```
