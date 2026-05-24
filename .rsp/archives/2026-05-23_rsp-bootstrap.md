---
status: done
priority: high
tags:
  - rsp
  - workflow
  - bootstrap
---

# Feature: rsp-bootstrap

## Spec
- Summary: 将初始化后的 `.rsp/` 骨架补齐为可直接使用的项目工作流文档。
- Requirements:
  - `design.md` 反映该仓库真实的架构目的、边界、目录职责与约束。
  - 项目级规则记录本仓库长期有效的验证方式与实现约定。
  - `.rsp` 中不再保留初始化模板占位符作为有效内容。
- Constraints:
  - 仅写入稳定、长期有效的项目信息，不把 README 的操作步骤复制到设计规格中。
  - 优先使用 RSP CLI 创建和维护受其管理的文件与索引。

## Plan
- [x] Phase 1: 阅读 `.rsp` 骨架、README、flake 入口以及 host/module/lib 结构。
- [x] Phase 2: 提炼长期设计信息并回填 `design.md` 与 `project-rules.md`。
- [x] Phase 3: 用 `rsp check`、`rsp status` 和索引重建验证工作流状态。

## Tests
- [x] `npx -y @oevery/rsp check`
- [x] `npx -y @oevery/rsp status`
- [x] `npx -y @oevery/rsp specs-index`

## Notes (optional)
- 本仓库当前没有明确的活跃功能开发项，因此使用 `rsp-bootstrap` 记录一次性的工作流落地过程。
- 项目最稳定的事实来自 `flake.nix`、`lib/`、`hosts/` 与模块分层，而不是 README 中的操作命令。

## Blockers
- 无。
