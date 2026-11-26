# 日常命令速查

## 验证配置

| 目的 | 命令 | 验证范围 |
| --- | --- | --- |
| 快速检查当前主机 | `hc` | 求值当前主机，不构建、不激活 |
| 检查所有已注册主机 | `nix flake check --all-systems --no-build --no-write-lock-file ~/.config/home-manager` | 跨平台求值，不构建 |
| 构建当前平台 | `nix flake check --no-write-lock-file ~/.config/home-manager` | 构建当前平台的检查项，不激活；Linux 原生构建在 Linux 运行 |

单独排查某个输出时，可在仓库根目录运行：

```bash
nix eval --raw --no-write-lock-file '.#homeConfigurations.oevery-homelab.activationPackage.drvPath'
nix eval --raw --no-write-lock-file '.#darwinConfigurations.oevery-mac.config.system.build.toplevel.drvPath'
```

## 更新与切换

| 命令 | 何时使用 |
| --- | --- |
| `flu` 或 `flu <input>` | 更新全部或指定 flake 输入，修改锁文件，不激活 |
| `brewup`（macOS） | 更新锁定的 Homebrew 引擎并验证构建，不升级已安装应用 |
| `hms` / `hmst`（Linux） | 先运行 `hc`，成功后切换用户环境；`hmst` 在切换时显示错误调用栈。不更新 Debian、系统 daemon 或 Docker |
| `drs` / `drst`（macOS） | 先运行 `hc`，成功后统一切换 nix-darwin 和 Home Manager；`drst` 在切换时显示错误调用栈 |

**`drs` 和 `drst` 不只是检查：** 切换会按锁定的 taps 升级 Homebrew 软件，并按 `zap` 规则清理已移出清单的 cask，可能删除应用偏好。只想检查配置时用 `hc` 或 `nix flake check`。

首次安装、尚无这些命令时，使用 [README 中的原生切换命令](../README.md#首次安装)。系统级操作另见 [Linux daemon 配置](linux-nix-conf.md)与 [macOS Mihomo 运维](mihomo.md)。

## 清理旧代

配置已安排每周 GC，保留最近 30 天的旧代。只有在愿意放弃当前用户全部旧代的回滚能力时才运行 `nix-gc-delete-all-old-generations`；日常维护不需要手动执行。
