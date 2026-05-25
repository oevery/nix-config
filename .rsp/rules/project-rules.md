---
name: project-rules
description: Project-specific rules for home-manager
---

# Project Rules

## Scope
- 这些规则适用于 `flake.nix`、`lib/`、`hosts/`、`modules/` 以及 `.rsp/` 中记录的长期项目约定。
- `README.md` 与 `docs/` 负责操作说明；稳定架构边界、命名约定和实现组织放入 `.rsp/specs/` 与 `.rsp/rules/`。

## Validation
- 优先运行 `nix flake check` 作为全仓标准验证。
- 需要快速确认输出是否可解析时，优先使用 `nix eval --raw path:$PWD#homeConfigurations.<name>.activationPackage.drvPath` 或对应 Darwin `toplevel.drvPath`。
- 调整 `.rsp/` 工作流文件后，先运行 `npx -y @oevery/rsp update`，再运行 `npx -y @oevery/rsp check` 和 `npx -y @oevery/rsp status`。

## Conventions
- 所有主机必须通过 `lib.mkHost` 定义，并在 `hosts/default.nix` 中统一注册。
- `homeConfigurationName` 与 `darwinName` 使用稳定、显式的输出名，不依赖运行时 `hostname`。
- `hosts/` 只描述主机元数据与模块集合，不承载具体实现逻辑。
- `modules/base/` 放跨平台能力，`modules/linux/` 与 `modules/darwin/` 只放平台差异。
- 新增模块组前先更新 `lib.moduleRegistry`，避免绕过允许模块列表。
- `home.nix` 保持为薄入口；通用配置应下沉到模块目录，而不是持续堆积在根模块中。
- `.rsp/features/*.md` 与 `.rsp/archives/*.md` 中的 `## Spec` 使用普通列表表达 `Summary`、`Requirements`、`Constraints`；不要在 `Spec` 小节使用 checkbox。
- checkbox 仅用于可执行或可验证的跟踪项，例如 `## Plan`、`## Tests`，以及确有状态语义的清单。
