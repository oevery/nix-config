# Project Design: home-manager

## Purpose
- 该仓库通过一个 Nix flake 统一管理多台主机的用户环境配置。
- 主要服务同一用户在 Linux 与 macOS 之间保持一致的开发环境、Shell、工具链与主机差异化设置。

## Scope
- In scope:
  - 维护 `homeConfigurations` 与 `darwinConfigurations` 两类输出。
  - 用 `hosts/` 中的主机声明和 `modules/` 中的模块组合生成最终配置。
  - 管理跨平台基础配置，以及 Linux、Darwin 各自的平台增量配置。
  - 在 macOS 上通过 `nix-darwin` 管理系统层配置，并嵌入 Home Manager。
- Out of scope:
  - NixOS 系统配置管理。
  - 安装步骤、日常命令速查、排障手册等操作文档。
  - 与项目设计无关的软件清单说明或临时使用笔记。

## Structure
- `flake.nix` - 仓库装配入口，导入 `lib/` 与 `hosts/`，生成所有 flake outputs，并处理 Darwin 特有的系统层集成。
- `lib/` - 规则与装配辅助层，提供 `moduleRegistry`、`mkAutoImports`、`mkHost` 等稳定基础设施。
- `hosts/` - 主机声明层，定义每台主机的 `system`、输出名、用户身份与模块组合；`hosts/default.nix` 是注册入口。
- `modules/base/` - 跨平台模块实现，承载大多数公共 Home Manager 配置。
- `modules/linux/` - Linux 专属模块实现，仅补充非 Darwin 平台差异。
- `modules/darwin/` - macOS 专属模块实现，区分用户态配置与 `system.nix` 等系统态配置。
- `home.nix` - 薄的公共 Home Manager 根模块，只保留全局基础项。
- `docs/` - 操作说明与排障文档，不承载长期设计事实。

## Constraints
- `homeConfigurations` 必须使用显式的 `homeConfigurationName`，`darwinConfigurations` 必须使用显式的 `darwinName`，且名称需非空、全局唯一。
- `hosts/*.nix` 应保持为声明数据，模块实现放在 `modules/`，通用装配逻辑放在 `lib/`。
- 主机可用的模块键只能来自 `lib.moduleRegistry`，避免在 host 文件中直接引入任意路径。
- 模块分层遵循 `base/*` 负责跨平台、`linux/*` 与 `darwin/*` 负责平台增量的边界。
- Linux 主机使用 `nixos-26.05` 包集；Darwin 主机及 `nix-darwin` 使用独立的 `nixpkgs-26.05-darwin` 包集，避免跨平台 channel 的二进制缓存覆盖差异。
- 模块目录默认通过 `myLib.mkAutoImports` 聚合子模块；Darwin 的 `system.nix`、GUI Homebrew 装配由上层显式接管。
- 长期稳定的架构约定写入 `.rsp/specs/` 与 `.rsp/rules/`；操作说明保留在 `README.md` 或 `docs/`。
