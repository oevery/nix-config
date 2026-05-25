---
kind: feature
priority: medium
---

# Change: kilo-zombie-cleaner

## Proposal
- Summary: 跨平台定时清理 Kilo Code、MCP 服务及命令遗留孤儿/僵尸进程的自动化脚本，通过 launchd (macOS) / systemd timer (Linux) 自动调度执行。
- Why:
  - 将清理逻辑保留在单个 shell 脚本中，并按平台接入定时任务
- Scope:
  - `modules/base/core/kilo-cleaner/`
  - macOS 的 launchd 用户代理配置
  - Linux 的 systemd 用户定时器配置
- Non-goals:
  - 避免额外运行时依赖，并保持清理作用于当前用户

## Spec
### 新增
- 需求：进程清理自动化
  - 脚本可识别并清理 Kilo Code 和 MCP 相关的孤儿/僵尸进程
  - 脚本具备幂等性，并记录其执行行为
  - 清理任务在 macOS 和 Linux 上自动由定时器触发

### 修改
- 需求：跨平台打包
  - 脚本使用 shell 和标准 Unix 工具实现，并通过 `pkgs.writeShellApplication` 打包
  - 模块位于 `modules/base/core/kilo-cleaner/`，并通过自动导入加载

### 验收
#### 场景：清理脚本可用
- GIVEN a supported host
- WHEN the configuration is applied
- THEN the `kilo-cleaner` script is available in PATH
- AND its scheduled timer is configured for the host platform

## Design
- 方案：
  - 将清理逻辑保留在单个 shell 脚本中，并按平台接入定时任务
- 影响范围：
  - `modules/base/core/kilo-cleaner/`
  - macOS 的 launchd 用户代理配置
  - Linux 的 systemd 用户定时器配置
- 约束：
  - 避免额外运行时依赖，并保持清理作用于当前用户

## Plan
- [x] 实现清理脚本与模块接线
- [x] 配置 macOS 的 launchd 和 Linux 的 systemd 定时器
- [x] 验证配置可构建且脚本运行无报错

## Tests
- [x] 当不存在匹配进程时脚本退出码为 0
- [x] 模拟的 Kilo/MCP 进程可以被识别并终止
- [x] `plutil -lint` 可验证 macOS launchd plist
- [ ] `systemd-analyze verify` 可验证 Linux unit 文件
- [x] `nix flake check` 无回归

## Blockers
- 当前会话中无法使用 Linux 实机环境，因此 Linux 侧最终验证仍待补充
- 当前会话未执行实际的 `home-manager switch` / `darwin-rebuild switch`

## 备注
- 进程匹配采用保守策略，优先发送 SIGTERM，超时后再发送 SIGKILL
- 日志目录遵循 XDG 规范，并在首次运行时创建
