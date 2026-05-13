# Commands Cheat Sheet

## Core

```bash
# 更新依赖
nix flake update --flake ~/.config/home-manager

# 当前 host 检查
hc

# 标准检查
nix flake check
```

## Linux (Home Manager)

```bash
# 推荐
hms

# 原生命令
home-manager switch --flake ~/.config/home-manager#<homeConfigurationName>
```

## macOS (nix-darwin)

```bash
# 推荐
drs

# 调试
drst

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
