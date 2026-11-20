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

nix-darwin 安装 Mihomo 和 LaunchDaemon，首次激活时提供占位配置。默认不自启，需要时手动运行 `mihomoctl start`；进程退出后不会自动重启。开启自启后，独立任务只在新的开机会话尝试启动一次，`drs` 重载任务不会触发启动。
首次启动使用实际配置的 Mihomo 前，先退出 Verge 或关闭它的 TUN 和可能冲突的监听端口。
独立 EasyTier 可以继续运行；不要给 Mihomo 的原生 EasyTier 出站配置同一个虚拟 IP。

```bash
mihomoctl status                         # 分开查看开机自启和运行状态
mihomoctl config set-source 'https://…'  # Mac 的 Surgio 完整配置地址
mihomoctl config update                  # 从已保存的地址更新
mihomoctl restart                        # 重启；未加载时尝试启动
mihomoctl stop                           # 停止服务，不改变开机自启
mihomoctl start                          # 手动启动
mihomoctl disable                        # 关闭开机自启，不停止当前进程
mihomoctl enable                         # 从下次开机起自启，不立即启动
tail -F /Library/Logs/Mihomo/{stdout,stderr}.log
```

- `set-source` 只接受可信的 HTTPS 完整配置（含 `rules`），不是节点订阅。含凭据的地址请用 `mihomoctl config set-source --stdin`，从凭据管理器通过管道提供，避免出现在参数或历史里。
- 更新先用 `mihomo -t` 校验。配置有变化且服务原本在运行时才重启，只确认新进程稳定存活；重启失败或更新中按 `Ctrl-C` 会回滚配置和源地址，暂不处理 `SIGTERM`。服务原本停止时只安装配置，下次 `start` 生效。首次切换或改端口、DNS、TUN 时，请另看日志并验证连通性。
- 配置与状态保存在 `/Library/Application Support/Mihomo/`。新建目录和文件默认由 `root:admin` 管理，目录 `0755`、文件 `0644`；本机用户可读配置、订阅地址和日志，但不能写入。已有路径不会自动调整权限。`mihomoctl` 仍按需调用 `sudo`。不要直接把 Verge 目录软链过来。节点和规则 provider 仍按配置中的 `interval` 刷新。
- `org.nixos.mihomo.logrotate` 每小时检查两个日志文件，各自按 `10 MiB` 阈值轮转、压缩并保留最近 5 份。使用 `copytruncate`，不重启 Mihomo，也不改变 TUN 状态；轮转时可能漏掉少量日志。
- 自启设置保存在 `/Library/Application Support/Mihomo/autostart`；关闭自启不影响手动启动。想同时关闭自启和停止服务，请分别执行 `disable` 和 `stop`。

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
