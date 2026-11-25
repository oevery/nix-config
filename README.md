# nix-config

这份配置管理三台主机：两台 Linux 使用独立的 Home Manager，一台 Mac 由 nix-darwin 同时管理系统和用户环境。第一次安装从下文开始；已安装的主机直接看[日常命令速查](docs/commands-cheatsheet.md)。

## 快速开始

### 1. 安装 Nix

推荐使用清华镜像（多用户模式）：

```bash
sh <(curl -L https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon
```

官方安装脚本：

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 2. 拉取仓库

```bash
git clone https://github.com/oevery/nix-config ~/.config/home-manager
cd ~/.config/home-manager
```

### 3. 首次应用

在仓库根目录执行对应平台的命令，重建工具和主机配置均使用本仓库的 `flake.lock`。

**Linux（Home Manager）：** 若尚未启用 flakes，在 `/etc/nix/nix.conf` 中加入 `extra-experimental-features = nix-command flakes`。按机器选择 `oevery-homelab` 或 `oevery-desktop`：

```bash
host=oevery-homelab
nix run ".#homeConfigurations.$host.config.programs.home-manager.package" -- switch --flake ".#$host"
```

**macOS（nix-darwin）：** 先以当前桌面用户登录 Mac App Store，激活时会从商店安装 Xcode 和 AndroMeld。下面的命令仅为本次调用启用 flakes，无需先修改 `/etc/nix/nix.conf`；首次激活成功后由 nix-darwin 管理该文件。

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run .#darwin-rebuild -- switch --flake .#oevery-mac
```

### 4. 检查首装结果，按需安装 Rust

切换成功后新开终端，运行 `hc`。Linux 应输出一个 `.drv` 路径，Mac 应输出两个；这说明当前主机的配置能够求值。需要 Rust 时，在仓库目录运行：

```bash
mise install rust
mise exec -- rustc --version
mise exec -- cargo --version
```

Nix 安装 mise，但不在激活时下载 Rust。mise 首次安装 Rust 需要联网，已有的 `~/.cargo` 和 `~/.rustup` 保留。

## 日常使用

Linux 在已加载本配置的交互式 Zsh 中用 `hms`；Bash 等其他 shell 使用[速查中的 `home-manager switch` 命令](docs/commands-cheatsheet.md#linux-home-manager)。Mac 用 `drs` 做日常维护，包括 Homebrew 升级和清理。`hms` 和 `drs` 都会先检查当前主机，不必手动再跑一次 `hc`。

- 更新依赖、只验证不激活、管理 Mihomo 或清理旧代：见[命令速查](docs/commands-cheatsheet.md)。
- Linux 多用户 Nix 的 daemon 设置：见 [Linux 配置参考](docs/linux-nix-conf.md)。Mac 对应设置在 [nix-darwin 系统模块](modules/darwin/nix-darwin/core.nix)。
- macOS 提示应用“已损坏”：先按 [Quarantine 排障](docs/quarantine.md)检查来源和签名。

### Git 身份

Git 默认使用主机声明的 `gitName` 和 `email`，无需解密密钥。需要按目录切换身份时，在主机声明中设置 `enablePrivateGit = true`。目录规则和对应身份保存在同一份 [SOPS 密文](secrets/git.yaml) 中，不写入明文 Nix 配置。

- **准备密钥**：激活前，将已获授权的 age 私钥保存在 `~/.config/sops/age/keys.txt`，权限设为 `0600`。私钥在仓库外备份，并用备份验证密文可解。
- **编辑配置**：在仓库根目录运行 `SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops edit secrets/git.yaml`。`routing` 保存 Git 的 `includeIf` 规则，以相对路径 `profile-01.inc` 引用 `profile_01` 中的身份设置。修改后重新激活。
- **验证身份**：在匹配和不匹配规则的仓库中分别运行 `git config --show-origin --get user.email`。前者应来自 `profile-01.inc`，后者应保留默认身份。若仓库另设了 `user.email`，它会覆盖上述配置。

## 新增主机

1. 以 [homelab](hosts/oevery-homelab.nix)、[Linux 桌面](hosts/oevery-desktop.nix)或 [Mac](hosts/oevery-mac.nix) 为范本，在 `hosts/` 用 `mkHost` 声明主机。选择匹配会话的 `pinentryPackage`：无图形会话用 `pinentry-curses`，GNOME 用 `pinentry-gnome3`，macOS 用 `pinentry_mac`。
2. 在 [主机注册表](hosts/default.nix) 注册。`homeConfigurationName` 必须唯一；Mac 还需要唯一的 `darwinName`。`modules` 只接受[模块注册表](lib/default.nix)中的键。
3. 将新主机文件加入 Git 跟踪后，按[验证命令](docs/commands-cheatsheet.md#core)先做全平台求值，再在目标平台构建。主机与模块的分工见[项目设计](.rsp/specs/design.md)。

### 生成 hosts gpgKey

需要默认签名且尚无密钥时，先生成签名密钥（`0` 表示不过期）；已有密钥则跳过此命令。

```bash
gpg --quick-generate-key "Your Name <you@example.com>" ed25519 sign 0
```

查看 Key ID，将输出写入主机声明的 `gpgKey`：

```bash
gpg --list-secret-keys --keyid-format LONG --with-colons you@example.com | awk -F: '$1=="sec"{print $5}'
```

不设置 `gpgKey` 时，该配置不会默认签名。
