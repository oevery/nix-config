# nix-config

这份 Nix flake 让 Linux 和 macOS 共用 Shell、开发工具和用户配置。Linux 由 Home Manager 管理当前用户的环境，不接管宿主系统；macOS 由 nix-darwin 一次应用系统设置和 Home Manager 配置。已完成安装的用户可直接查看[日常命令速查](docs/commands-cheatsheet.md)。

## 首次安装

### 1. 安装 Nix 并获取配置

需要 Git 和多用户模式的 Nix。若尚未安装 Nix，可以使用官方安装脚本；也可将脚本地址换为[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install)。

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

新开终端，确认 `nix --version` 可用，再获取仓库。日常维护命令按以下路径查找配置：

```bash
git clone https://github.com/oevery/nix-config ~/.config/home-manager
cd ~/.config/home-manager
```

### 2. 选择主机配置

从[主机注册表](hosts/default.nix)选择与目标系统、架构和用户名匹配的配置。命令里的名称是 **flake 输出名**，不必与系统 hostname 相同。以下是仓库当前的示例；如果目标设备不匹配，请先[新增主机](#新增主机)。

| 平台 | 配置声明 | Home Manager 输出名 | nix-darwin 输出名 |
| --- | --- | --- | --- |
| Linux x86_64 | [Linux 示例](hosts/oevery-homelab.nix) | `oevery-homelab` | — |
| macOS Apple Silicon | [macOS 示例](hosts/oevery-mac.nix) | `oevery-mac` | `oevery-mac` |

首次激活前，检查所选配置的两个条件：

- **私有 Git 或设备签名：** 如果主机启用了 `enablePrivateGit`，或有专属的 GPG 签名密文，先按 [Git 身份与设备授权](docs/git-identity.md)准备 age 身份，并确认目标用户能解密对应文件。两项都未配置时，可以跳过。
- **Mac App Store 应用：** 如果 macOS 配置声明了 `masApps`，先以目标桌面用户登录 App Store。

### 3. 验证并激活

以下命令均在仓库根目录运行。可先在目标平台构建检查项，**不激活**：

```bash
nix --extra-experimental-features 'nix-command flakes' flake check --no-write-lock-file
```

检查通过不代表凭据可解密。确认已满足上一步的条件后，按平台选择一条激活命令，将示例输出名替换为所选配置的名称：

**Linux：** homelab 的系统设置由管理员按 [Linux daemon 接入教程](docs/linux-nix-conf.md)单独安装。下面的命令只切换目标用户的环境，无需 `sudo`，也不会安装或更新 daemon 配置：

```bash
home_name=oevery-homelab
nix --extra-experimental-features 'nix-command flakes' run ".#homeConfigurations.${home_name}.config.programs.home-manager.package" -- switch --flake ".#${home_name}"
```

**macOS：** 使用 `darwinName` 对应的输出，一次激活系统和用户配置，无需再单独运行 `home-manager switch`：

```bash
darwin_name=oevery-mac
sudo nix --extra-experimental-features 'nix-command flakes' run .#darwin-rebuild -- switch --flake ".#${darwin_name}"
```

激活后新开终端，运行 `hc`。Linux 应输出一个 `.drv` 路径，macOS 应输出两个；这表示所选配置可以求值。私有 Git 的身份匹配、SSH 访问和提交签名需[分别验证](docs/git-identity.md)。

## 日常使用

| 任务 | Linux | macOS |
| --- | --- | --- |
| 只检查当前主机，不激活 | `hc` | `hc` |
| 检查后应用配置 | `hms` | `drs` |
| 切换时显示错误调用栈 | `hmst` | `drst` |

`hms` 只切换用户环境；`drs` 还会执行配置中声明的 Homebrew 升级和清理。仅需验证时不要运行切换命令。

Rust 由 mise 按需安装，而不是在激活时下载。需要时运行 `mise install rust`，再用 `mise exec -- rustc --version` 和 `mise exec -- cargo --version` 检查。首次安装需要联网，已有的 `~/.cargo` 和 `~/.rustup` 会保留。

- [命令速查](docs/commands-cheatsheet.md)：更新 flake、构建检查和清理旧代。
- [macOS Mihomo 运维](docs/mihomo.md)：设置完整配置源、管理进程与开机自启、检查更新和日志。
- [Linux Nix daemon 配置](docs/linux-nix-conf.md)和 [macOS 系统模块](modules/darwin/nix-darwin/core.nix)：区分用户设置与系统设置。
- [macOS Quarantine 排障](docs/quarantine.md)：应用提示“已损坏”时，先检查来源和签名。

## 新增主机

1. 在 `hosts/` 中参考同平台示例，用 `mkHost` 声明系统、用户和模块组。`modules` 只接受[模块注册表](lib/default.nix)中的名称。
2. 按使用场景选择 `pinentryPackage`：无图形会话用 `pinentry-curses`，GNOME 可用 `pinentry-gnome3`，macOS 用 `pinentry_mac`。仅在设备应持有共享 Git SSH 私钥时启用 `enablePrivateGit`。
3. 在[主机注册表](hosts/default.nix)注册。`homeConfigurationName` 必须唯一；macOS 还需在 Darwin 输出中唯一的 `darwinName`。将新文件加入 Git 跟踪，否则 Git flake 看不到它们。
4. 按[验证命令](docs/commands-cheatsheet.md#验证配置)先对所有平台求值，再在目标平台构建，最后按首次安装步骤激活。主机与模块的职责见[项目设计](.rsp/specs/design.md)。
