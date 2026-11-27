---
kind: "refactor"
summary: "主机按操作系统和架构装配 Magpie、Multica、OMP 和 Mihomo；Multica 与 OMP 可独立启用，Mihomo 服务仍仅适配 macOS。"
---

# Change: app-platform-modules

## Proposal
主机按应用名选择能力，应用就近维护平台适配、安装助手和使用说明。保留现有主机行为，不部署、不改变 Mac 桌面应用或用户状态。

## Spec
### MODIFIED
- Requirement: 主机按 `system` 和所选应用确定 Home Manager 与 nix-darwin 入口；适配不存在时求值失败。

### Acceptance
#### Scenario: Mac 选择系统服务
- GIVEN Mac 选择 `apps/mihomo`
- WHEN 单独求值 Home Manager 或组装完整的 Darwin 配置
- THEN 只有系统层接管 Mihomo；不再需要第二个开关。

#### Scenario: Linux 工具独立装配
- GIVEN 主机分别或同时选择 Multica 和 OMP
- WHEN 组装用户环境
- THEN 只安装所选能力；两者同选时 runner 的搜索路径包含提供 OMP 的 profile。

## Design
注册表仅索引应用；装配层从主机 `system` 选择操作系统实现，再校验该实现支持的架构，最后取管理层入口。下载上游二进制的应用从产物映射生成架构清单。基础模块保留原装配方式。Mac cask 不属于此次网关或 runner 适配；跨应用接单流程保留一份组合指南。

## Tasks
- [x] 实现平台选择和分层装配，迁移四个应用及主机声明。
- [x] 同步应用文档、组合指南与设计规范。

## Verify
### Required
- [x] 对四个应用逐一求值：6 个原有支持组合进入正确管理层，22 个不支持或无效的组合保留完整 `system` 报错。Magpie 和 Multica 的安装器在同时含 ARM64 和 AMD64 的样例中均选中原 AMD64 产物。
- [x] 验证未知应用、未支持平台、单选与组合、Mac 系统服务及 cask 边界：独立 Home Manager 不导入 Mihomo，系统配置保留三个 Mihomo 服务和两个桌面 cask。
- [x] 两台已注册主机通过 `nix flake check --all-systems --no-build --no-write-lock-file` 求值，Mac 通过 `nix flake check --no-write-lock-file` 构建。OMP 的三个适配都能从锁定包集求值。
### Optional
- [ ] homelab 激活后的实际派单、网关切换及 Mac 服务的实机验收均未执行。

## Blockers
None
