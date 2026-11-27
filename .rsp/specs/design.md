# Project Design: home-manager

## Purpose
用同一个 Nix flake 管理个人 Linux 与 macOS 主机的开发环境，在共享 Shell 和工具链的同时保留主机差异。

## Boundaries
- 所有主机都提供 `homeConfigurations`；macOS 另提供 `darwinConfigurations`，由 nix-darwin 统一激活系统和嵌入的 Home Manager。
- Linux 使用独立的 Home Manager，不接管 NixOS 或宿主操作系统。

## Contracts
- 主机通过 `lib.mkHost` 声明并在 `hosts/default.nix` 注册。`homeConfigurationName` 与 `darwinName` 是显式、非空、在各自输出集合内唯一的稳定名称，不依赖运行时 hostname。
- 主机声明只组合 `lib.moduleRegistry` 中允许的模块组，不直接导入任意路径或实现模块逻辑。
- [flake 输出](../../flake.nix)的 `checks` 按平台覆盖所有已注册主机的 Home Manager 激活包，并包含该平台的 Darwin 系统构建。求值、构建、激活是三个不同的结果。
- Homebrew tap 源由 `nix-homebrew.taps` 统一声明，运行时不可改写，`homebrew.taps` 从中生成；tap 和单个 cask 的信任策略分别维护。`flake.lock` 锁定引擎与外部 tap 源，不是已安装应用或其用户数据的快照。

## Structure
- `flake.nix` 组合 `hosts/` 的声明与 `lib/` 的装配逻辑。`home.nix` 保持为薄入口；公共实现放在 `modules/base/`，`modules/linux/` 与 `modules/darwin/` 只负责平台差异。
- 基础模块组可使用 `myLib.mkAutoImports` 聚合。应用集中在 `modules/apps/<应用>/`：`default.nix` 先按 `host.system` 的操作系统选择实现，再校验架构是否在该平台的 `architectures` 中；任一项不支持都以完整 `system` 报错。校验通过后，`home` 和 `darwin` 分别由 Home Manager 和 nix-darwin 导入，缺少当前管理层入口时跳过该层。私有安装助手、包和运维说明与应用同目录，不自动导入。

## Constraints
- Linux 与 Darwin 使用各自的稳定 nixpkgs 输入，以匹配平台的二进制缓存；nix-darwin 跟随 Darwin 输入。`nixpkgs-unstable` 独立锁定，只供显式选择的软件使用，不替换默认包集。具体分支以 [flake inputs](../../flake.nix) 为准。
- `apps/mihomo` 由 nix-darwin 管理内核与 LaunchDaemon；`mihomoctl` 保留 systemd 后端，但没有 Linux 服务适配。可变配置、订阅凭据和状态不写入 Nix store。
- `apps/multica` 与 `apps/omp` 可单独启用；同选时 runner 通过用户 profile 发现 OMP。Linux 的 Magpie 网关和 Multica runner 不接管 Mac 的桌面 cask。
