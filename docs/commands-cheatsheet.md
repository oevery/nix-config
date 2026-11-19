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

### Mihomo（macOS）

首次激活后，`org.nixos.mihomo` 使用占位配置启动，不监听端口、不接管 TUN。
在应用第一份实际配置前，先退出 Verge 或关闭它的 TUN 和可能冲突的监听端口。
独立 EasyTier 可以继续运行；不要给 Mihomo 的原生 EasyTier 出站配置同一个虚拟 IP。

```bash
mihomoctl status
mihomoctl config set-source 'https://…'  # Mac 的 Surgio 完整配置地址
mihomoctl config update                  # 从已保存的地址更新
mihomoctl restart                        # 重启；未加载时尝试启动
mihomoctl stop                           # 本次停用，不改变开机设置
mihomoctl start
mihomoctl disable                        # 禁止后续启动，不停止当前进程
mihomoctl enable                         # 解除禁用，不立即启动
sudo tail -F /Library/Logs/Mihomo/{stdout,stderr}.log
```

- `set-source` 只接受可信的 HTTPS 完整配置（含 `rules`），不是节点订阅。含凭据的地址请用 `mihomoctl config set-source --stdin`，从凭据管理器通过管道提供，避免出现在参数或历史里。
- 更新先用 `mihomo -t` 校验。配置有变化且服务原本在运行时才重启，只确认新进程稳定存活；重启失败或更新中按 `Ctrl-C` 会回滚配置和源地址，暂不处理 `SIGTERM`。服务原本停止时只安装配置，下次 `start` 生效。首次切换或改端口、DNS、TUN 时，请另看日志并验证连通性。
- 配置与状态保存在 `/Library/Application Support/Mihomo/`，由 root 管理；普通用法会按需调用 `sudo`。不要直接把 Verge 目录软链过来。节点和规则 provider 仍按配置中的 `interval` 刷新。
- `org.nixos.mihomo.logrotate` 每小时检查两个日志文件，各自按 `10 MiB` 阈值轮转、压缩并保留最近 5 份。使用 `copytruncate`，不重启 Mihomo，也不改变 TUN 状态；轮转时可能漏掉少量日志。
- 禁用后若也想立即停用，再执行 `stop`。nix-darwin 重新安装或更新 LaunchDaemon 定义时可能重新启用服务。

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
