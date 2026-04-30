# nix-config

这是我的个人 Nix/Home Manager 配置仓库，用于统一管理开发环境与终端体验，并支持多主机复用。

## 架构说明

- `hosts/`：仅存放主机数据（系统类型、身份信息、启用模块）
- `modules/`：可复用模块，按平台与层级组织（`base`、`linux`、`darwin`）
- `lib/`：共享工具函数（`mkHost`、`mkAutoImports`、模块注册表）
- `flake.nix`：根据 `hosts` 定义生成 `homeConfigurations`

每台主机通过 `modules` 字段选择需要的模块，例如：

```nix
modules = [
  "base/core"
  "linux/core"
];
```

模块键会由 `lib.mkHost` 进行校验，避免拼写错误或非法值。

## 从零开始安装与应用配置

本节提供从「未安装 Nix」到「成功应用本仓库配置」的完整流程。

### 1. 使用清华镜像安装 Nix

建议先尝试清华镜像安装脚本（多用户模式，推荐）：

```bash
sh <(curl -L https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon
```

如果镜像脚本不可用，可回退到官方安装脚本：

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

安装完成后，重新登录终端，确认 Nix 可用：

```bash
nix --version
```

### 2. 配置优先级（先看这个）

- Linux（非 NixOS）：以 `/etc/nix/nix.conf` 为主。
- macOS（已启用 nix-darwin）：以 `modules/darwin/core/system.nix` 中的 `nix.settings` 为主。

也就是说，macOS 上建议把长期配置放在 nix-darwin 模块中，避免和 `/etc/nix/nix.conf` 双处维护。

### 2.1 Linux: 优化 `/etc/nix/nix.conf`

在 Linux（或尚未接入 nix-darwin 的临时阶段）可编辑 `/etc/nix/nix.conf`，建议至少包含：

```nix
build-users-group = nixbld
# 启用 nix-command 与 flakes
experimental-features = nix-command flakes
# 中国大陆网络环境可使用清华镜像
substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
# 允许以下用户操作 Nix daemon
trusted-users = root oevery
# 启用沙箱构建，提高可复现性
sandbox = true
# 自动去重 store 中重复文件
auto-optimise-store = true
# 保留输出与 derivation，便于调试和复用
keep-outputs = true
keep-derivations = true
# 构建器可使用二进制缓存
builders-use-substitutes = true
# 允许 flake 中定义的缓存配置生效（常见于现代 flake 项目）
accept-flake-config = true
# 网络不稳定时更稳健
connect-timeout = 10
fallback = true
# 提升下载并发与体验（按机器性能可调整）
max-jobs = auto
```

修改后可重启 daemon（不同平台命令可能略有差异），或直接重启系统。

macOS 上如果你使用多用户安装，配置文件同样是 `/etc/nix/nix.conf`。
如果是单用户安装，通常位于 `~/.config/nix/nix.conf`。
但在你已经用 `darwin-rebuild` 应用本仓库后，建议以 `modules/darwin/core/system.nix` 为准。

### 3. 克隆仓库并进入目录

```bash
git clone https://github.com/oevery/nix-config ~/.config/home-manager
cd ~/.config/home-manager
```

### 3.1 macOS 主机名检查（首次接入建议）

本仓库已预置示例主机条目：`oevery@macbook-air`。
在 macOS 上请先确认你的主机名是否一致：

```bash
whoami
hostname
```

如果主机名不是 `macbook-air`，请在 `hosts/default.nix` 中新增或修改对应条目。

### 3.2 macOS 启用 nix-darwin（推荐）

本仓库已内置 `nix-darwin` 基础系统配置，包含：

- `nix.enable` 与常用 `nix.settings`
- 常用 `system.defaults`（Dock/Finder/键盘/触控板）
- `Touch ID for sudo`
- 与 Home Manager 的一体化集成

首次在 macOS 上应用系统配置可使用：

```bash
nix run nix-darwin#darwin-rebuild -- switch --flake .#macbook-air
```

后续可继续使用同一命令更新系统层配置。

### 3.3 macOS 软件安装：是否必须使用 Homebrew？

结论：本仓库通过 `darwin/gui` 模块启用 Homebrew，并统一纳入声明式管理。

推荐优先级：

1. 能用 `nixpkgs` 的软件优先放到 Nix/Home Manager（可复现、跨机一致）。
2. `nixpkgs` 不方便或缺失的 GUI 应用，再用 Homebrew Cask 补充。

原因：

- Nix 负责开发环境与跨平台一致性。
- Homebrew 负责补齐 macOS 生态中的 GUI/App Store 应用。
- 在 `darwin/gui` 中启用 Homebrew 的成本很低（磁盘与内存开销可忽略），但可减少后续手动维护成本。

默认策略（Nix + Homebrew）：

- 系统/CLI 用 Nix。
- GUI 与部分 Apple 生态应用用 Homebrew。

追新策略（当前仓库）：

- 主包集统一使用 `nixpkgs-unstable`，优先获得新版本软件与修复。
- `home-manager` 与 `nix-darwin` 也跟随上游主线分支，减少跨分支兼容负担。
- 代价是波动更高，建议通过锁文件与定期验证控制升级风险。

`nix-darwin` 中可声明式管理 Homebrew。

本仓库当前在 `modules/darwin/gui/homebrew.nix` 维护 Homebrew 配置；当主机启用 `darwin/gui` 模块时会自动接入。如需自定义，可直接编辑该文件。

应用方式：

```bash
nix run nix-darwin#darwin-rebuild -- switch --flake .#macbook-air
```

如果你是本地已有仓库，直接进入目录即可：

```bash
cd ~/.config/home-manager
```

### 4. 首次应用配置（无需预装 home-manager）

首次推荐使用 `nix run` 方式引导：

```bash
nix run github:nix-community/home-manager -- switch --flake .#$(whoami)@$(hostname)
```

如果你已经安装过 `home-manager`，可直接执行：

```bash
home-manager switch --flake .#$(whoami)@$(hostname)
```

如果要显式切到预置的 macOS 示例主机，可执行：

```bash
home-manager switch --flake .#oevery@macbook-air
```

如果你已使用 `nix-darwin`，更推荐通过 `darwin-rebuild` 统一切换系统层与用户层：

```bash
nix run nix-darwin#darwin-rebuild -- switch --flake .#macbook-air
```

### 5. 验证配置是否生效

先验证 flake 输出可求值：

```bash
nix eval --raw path:$PWD#homeConfigurations."$(whoami)@$(hostname)".activationPackage.drvPath
```

再查看仓库内置检查项：

```bash
SYS="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix eval --json ".#checks.${SYS}"
```

macOS 也可单独检查 nix-darwin 输出是否可求值：

```bash
nix eval --raw path:$PWD#darwinConfigurations.macbook-air.config.system.build.toplevel.drvPath
```

若以上命令正常返回 derivation 或 JSON，说明配置链路基本正常。

也可使用标准 flake 检查（推荐）：

```bash
nix flake check
```

### 6. 日常更新

更新依赖并重新应用：

```bash
flu
hc
```

应用配置建议按平台执行：

- Linux（Home Manager）：直接执行 `hms`（已内置 `hc` 预检）
- macOS（nix-darwin）：直接执行 `drs`（已内置 `hc` 预检；优先用当前 `hostname`，失败回退到 hosts 里的预置主机）

```bash
# Linux
hms
```

```bash
# macOS
drs
```

macOS 调试场景可使用：

```bash
drst
```

可选强校验（更全面但更慢）：

```bash
nix flake check --show-trace
```

如果你尚未加载这些 alias，可使用原生命令：

```bash
nix flake update --flake ~/.config/home-manager
SYS="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix eval --json ".#checks.${SYS}"
# Linux
home-manager switch --flake ~/.config/home-manager#$(whoami)@$(hostname)
# macOS
nix run nix-darwin#darwin-rebuild -- switch --flake ~/.config/home-manager#$(hostname)
```

## 新增主机

1. 在 `hosts/` 下新增一个主机文件，使用 `mkHost` 定义数据。
2. 在 `hosts/default.nix` 中注册该主机。
3. 执行以下命令验证配置可求值：

```bash
nix eval --raw path:$PWD#homeConfigurations."<user>@<host>".activationPackage.drvPath
```

## 常见问题

### 找不到当前主机配置

报错通常是 `hosts/default.nix` 未注册 `<user>@<host>`，或主机名与 `hostname` 输出不一致。

可先检查主机名：

```bash
hostname
whoami
```

### `modules` 字段报错

`hosts/*.nix` 中的 `modules` 只能使用仓库支持的模块键，非法值会被 `mkHost` 拦截并报错。

### macOS 首次切换时报找不到 host

请检查 `hosts/default.nix` 是否包含与你实际 `whoami@hostname` 一致的键。
如果不一致，可复制 `hosts/oevery-macbook-air.nix` 新建一个主机文件并注册。
