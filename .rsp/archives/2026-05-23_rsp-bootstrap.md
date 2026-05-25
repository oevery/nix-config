---
kind: ops
priority: high
---

# Change: rsp-bootstrap

## Proposal
- Summary: 将初始化后的 `.rsp/` 骨架补齐为可直接使用的项目工作流文档。
- Why:
  - 将引导阶段知识保留在这一个变更中，同时把持久事实迁移到 specs 和 rules
- Scope:
  - `.rsp/specs/design.md`
  - `.rsp/rules/project-rules.md`
- Non-goals:
  - 保持引导流程轻量，避免重复写入持久项目事实

## Spec
### 新增
- 需求：项目引导捕获
  - 仓库的目的、范围和结构已反映到 `.rsp/specs/design.md`

### 修改
- 需求：稳定的本地运行约束
  - 稳定的验证或工作流约束在需要时反映到 `.rsp/rules/project-rules.md`

### 验收
#### 场景：项目模型已捕获
- GIVEN an initialized RSP project
- WHEN project setup is completed
- THEN `.rsp/specs/design.md` reflects durable project facts
- AND `.rsp/rules/project-rules.md` exists only when stable local rules are present

## Design
- 方案：
  - 将引导阶段知识保留在这一个变更中，同时把持久事实迁移到 specs 和 rules
- 影响范围：
  - `.rsp/specs/design.md`
  - `.rsp/rules/project-rules.md`
- 约束：
  - 保持引导流程轻量，避免重复写入持久项目事实

## Plan
- [x] 阅读仓库结构、入口和主要输出
- [x] 用持久的架构事实填充 `.rsp/specs/design.md`
- [x] 如存在稳定的本地规则或验证步骤，则补充 `.rsp/rules/project-rules.md`

## Tests
- [x] 运行 `rsp doctor`
- [x] 审阅 `.rsp/specs/design.md` 并确认其与仓库一致
- [x] 判断该变更是否产生应写入 `.rsp/specs/` 或 `.rsp/rules/` 的持久知识
- [x] 如有，则只把稳定事实写入最小的正确目标文件后再归档，不要提升任务历史、调试笔记或一次性实现细节

## Blockers
- none
