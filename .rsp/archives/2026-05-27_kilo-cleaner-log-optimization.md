---
kind: refactor
---

# Change: kilo-cleaner-log-optimization

## Proposal
- Summary: 优化 `kilo-cleaner` 日志输出与平台日志接线，减少噪音并保持日志可读。
- Why:
  - 当前运行日志会把同一条 terminate 事件拆成多行，且定时运行会持续写入 `start/done` 与重复 zombie 记录，排障体验较差。
  - Darwin 同时配置 `launchd.log` 与脚本自己的 daily log，形成无价值的双日志路径。
- Scope:
  - 调整 `modules/base/core/kilo-cleaner/package.nix` 的日志格式和扫描流程。
  - 调整 Linux/Darwin 平台接线中的日志目录和运行环境。
- Non-goals:
  - 不改变 Kilo/MCP 进程匹配策略。
  - 不引入长期运行守护进程或额外后台服务。

## Spec
### UPDATED
- Requirement: `kilo-cleaner` 日志保持单一来源且单行可读。
  - 清理脚本继续写入 `~/.local/state/kilo-cleaner/cleaner-YYYYMMDD.log` 或 `XDG_STATE_HOME/kilo-cleaner/cleaner-YYYYMMDD.log`。
  - 每个 terminate/force 事件应保持为一行，不因 descendants 列表换行。
  - 无实际动作且无异常条件时不写入 `start/done` 噪音日志。
  - Darwin 不再额外维护 `launchd.log` 业务日志。

### Acceptance
#### Scenario: 定时清理日志可读
- GIVEN `kilo-cleaner` 由定时任务运行
- WHEN 有孤儿 Kilo/MCP 进程被清理
- THEN 日志以单行事件记录清理动作和 descendants 列表
- AND 本次运行汇总以一行记录 terminated/skipped/zombies 计数

## Design
- Approach:
  - 保留脚本内 daily log 作为唯一业务日志来源。
  - 将 descendants 列表转换为逗号分隔的一行字段。
  - 改用已有 `ps_snapshot` 驱动主循环，避免再次调用 `ps`。
  - 将 zombie/skip 记录收敛到运行摘要，减少重复明细噪音。
- Affected areas:
  - `modules/base/core/kilo-cleaner/package.nix`
  - `modules/base/core/kilo-cleaner/default.nix`
  - `modules/darwin/core/kilo-cleaner.nix`
- Constraints:
  - 清理策略保持保守：先 SIGTERM，等待后仅对仍存活的目标 SIGKILL。
  - 日志保留策略仍限制在 daily log 文件。

## Tasks
- [x] Finalize the proposal, spec, and design details for this change
- [x] Optimize cleaner logging and platform log wiring
- [x] Verify the result and update any required durable docs or rules

## Verify
- Automated:
  - [x] `nix eval --raw path:$PWD#darwinConfigurations."oevery-mac".config.system.build.toplevel.drvPath`
  - [x] `nix build --impure --no-link --print-out-paths --expr 'let flake = builtins.getFlake "path:/Users/oevery/.config/home-manager"; pkgs = flake.inputs.nixpkgs.legacyPackages.aarch64-darwin; in import /Users/oevery/.config/home-manager/modules/base/core/kilo-cleaner/package.nix { inherit pkgs; }'`
  - [x] `bash -n /nix/store/1mj03a4dn2yylmyv22l3qj98lnrvrkmz-kilo-cleaner/bin/kilo-cleaner`
  - [x] `nix flake check`
  - [x] `nix eval --raw path:$PWD#homeConfigurations."oevery-desktop".activationPackage.drvPath`
  - [x] `nix eval --raw path:$PWD#homeConfigurations."oevery-homelab".activationPackage.drvPath`
- Manual:
  - [x] Review existing `~/.local/state/kilo-cleaner/*.log` to confirm current log noise and multiline descendants issue
  - [x] Skip direct `kilo-cleaner` execution because current live Kilo/MCP processes could be terminated by the cleaner
- Durable updates:
  - [x] Decide whether this change produced durable knowledge that belongs in `.rsp/specs/` or `.rsp/rules/`
  - [x] No durable spec/rule update needed; the stable behavior is encoded in the module and change file

## Blockers
- none
