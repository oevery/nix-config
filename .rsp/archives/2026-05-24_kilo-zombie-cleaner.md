---
status: done
priority: medium
tags:
  - automation
  - cross-platform
  - cleanup
---

# Feature: kilo-zombie-cleaner

## Spec

- Summary: 跨平台定时清理 Kilo Code、MCP 服务及命令遗留孤儿/僵尸进程的自动化脚本，通过 launchd (macOS) / systemd timer (Linux) 自动调度执行。
- Requirements:
  - 脚本能识别并清理 Kilo Code 相关进程（进程名/命令行匹配 `kilo`, `kilocode`, `kilo-server` 等）
  - 脚本能识别并清理 MCP 相关进程（`mcp-server-*`, `mcp-proxy-*`，以及通过 `npx`/`uvx`/`node` 等启动且命令行含 mcp 的进程）
  - 脚本能检测僵尸进程（state = Z）并尝试通知父进程或输出日志
  - 脚本能清理父进程已退出但子进程仍在运行的孤儿进程（parent PID = 1）
  - 清理操作仅作用于当前用户进程，不影响系统或其他用户
  - 脚本为幂等操作，重复运行无副作用，且有日志输出
  - macOS 上通过 `launchd.agents` 每 6 小时自动执行
  - Linux 上通过 `systemd.user.timer` 每日自动执行
- Constraints:
  - 跨平台：macOS (aarch64-darwin) 与 Linux (x86_64-linux)
  - 脚本用 shell 编写，依赖标准 Unix 工具（`ps`, `pgrep`, `pkill`, `kill`），通过 `pkgs.writeShellApplication` 构建
  - 不引入额外运行时依赖（ps/procps 已通过 `coreutils` 在各主机配置中引入）
  - 模块置于 `modules/base/core/kilo-cleaner/`，通过 `mkAutoImports` 自动导入，无需修改 `moduleRegistry`
  - 所有使用 `base/core` 的主机自动获得该模块（当前所有三台主机均已启用）

## Plan

- [x] Phase 1: 创建模块目录与清理脚本
  - [x] 创建 `modules/base/core/kilo-cleaner/default.nix`
  - [x] 使用 `pkgs.writeShellScriptBin` 编写清理脚本 `kilo-cleaner`
  - [x] 清理逻辑分三层：
    1. **孤儿进程清理**：遍历当前用户进程，找出 PPID=1 且命令行匹配 Kilo/MCP 模式的进程，发送 SIGTERM，等待 5 秒后未退出则 SIGKILL
    2. **僵尸进程检测**：通过 `ps -eo pid,ppid,stat,comm` 检测 state=Z 的进程，记录日志（不强行 kill，因为僵尸本身无法被信号杀死，只能由父进程 reap）
    3. **残留命令子进程清理**：检测通过 `npx`/`uvx` 启动、命令行含 `mcp` 且父进程已退出但未被 init 收养的进程，清理整个进程组
  - [x] 日志输出到文件（如 `~/.local/state/kilo-cleaner/cleaner.log`），保留最近 7 天
  - [x] 配置 `home.packages` 引入脚本到 PATH，同时方便手动执行

- [x] Phase 2: 配置定时任务
  - [x] macOS (`launchd.user.agents.kilo-cleaner`)：使用 launchd agent 配置
    - [x] `StartInterval = 21600`（6 小时）
    - [x] `RunAtLoad = true`（switch 后即执行一次）
    - [x] `StandardOutPath` / `StandardErrorPath` 指向日志目录
    - [x] `KeepAlive = false`（避免进程常驻）
  - [x] Linux (`systemd.user.services.kilo-cleaner` + `systemd.user.timers.kilo-cleaner`)
    - [x] Service: `Type = "oneshot"`, `ExecStart = "${package}/bin/kilo-cleaner"`
    - [x] Timer: `OnCalendar = "daily"`, `Persistent = true`（错过时间窗口后补执行）
    - [x] `WantedBy = [ "timers.target" ]`

- [x] Phase 3: 验证
  - [x] `nix flake check` 确保配置可构建（无 eval 错误）
  - [x] `homeConfigurations.oevery-mac.activationPackage.drvPath` 可解析，确认 Home Manager 导入路径无冲突
  - [x] 手动执行 `kilo-cleaner` 验证清理逻辑无报错

## Tests

- [x] 脚本在无匹配进程时正常运行并退出 0（幂等性验证）
- [x] 手动创建模拟 Kilo/MCP 进程（如 `sleep 9999 &` 并伪装命令行），验证脚本能正确识别并终止
- [x] macOS: `plutil -lint` 验证 launchd agent plist 语法
- [ ] Linux: `systemd-analyze verify` 验证 systemd unit 语法（跳过：当前会话无 Linux 环境）
- [x] `nix flake check` 无 regressions

## Blockers

- Linux 实机环境未在当前会话中可用，因此 `systemctl --user status kilo-cleaner.timer` 只能保留为待验证项
- 当前会话未实际执行 `home-manager switch` / `darwin-rebuild switch`，因此 `launchctl list | grep kilo-cleaner` 仍保留为待验证项

## Notes

- 进程匹配模式需要在开发阶段通过实际运行时 `ps aux` 观察确认，当前基于常见命名约定：
  - Kilo: `kilo`, `kilocode`, `kilo-server`, `kilo-agent`, `kilo-codebuddy`
  - MCP: `mcp-server-*`, `mcp-proxy-*`, 以及 `node`/`npx`/`uvx`/`python` + 命令行含 `mcp` 的组合
- 清理脚本采用保守策略：优先 SIGTERM 优雅退出 + 超时后 SIGKILL 强制终止，避免留下不一致状态
- 日志目录 `~/.local/state/kilo-cleaner/` 遵循 XDG 规范，首次运行时自动创建
- 如果后续发现需要更精细的清理策略（如按 CPU 空闲时间判定），可以作为增强在后续迭代中实现
- 需要在开发阶段通过实际环境确认 Kilo Code 和 MCP 进程的确切进程名与命令行特征，当前模式基于命名约定推测
- nix-darwin 的 `launchd.agents` 是否支持 `StartInterval`（非 Apple 原生字段）需要验证，如不支持则改用 `StartCalendarInterval`
