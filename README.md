# nix-config

这份配置管理 Linux homelab 和 Mac：homelab 使用独立的 Home Manager，Mac 由 nix-darwin 同时管理系统和用户环境。第一次安装从下文开始；已安装的主机直接看[日常命令速查](docs/commands-cheatsheet.md)。

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

**Linux homelab（Home Manager）：** 若尚未启用 flakes，在 `/etc/nix/nix.conf` 中加入 `extra-experimental-features = nix-command flakes`，然后运行：

```bash
nix run .#homeConfigurations.oevery-homelab.config.programs.home-manager.package -- switch --flake .#oevery-homelab
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

Linux 用 `hms` 切换当前用户的 Home Manager 环境；它是可执行命令，不依赖交互式 Zsh。Mac 用 `drs` 做日常维护，包括 Homebrew 升级和清理。两者都会先运行 `hc`；需要查看切换错误的调用栈时，Linux 用 `hmst`，Mac 用 `drst`。

- 更新依赖、只验证不激活、管理 Mihomo 或清理旧代：见[命令速查](docs/commands-cheatsheet.md)。
- Linux 多用户 Nix 的 daemon 设置：见 [Linux 配置参考](docs/linux-nix-conf.md)。Mac 对应设置在 [nix-darwin 系统模块](modules/darwin/nix-darwin/core.nix)。
- macOS 提示应用“已损坏”：先按 [Quarantine 排障](docs/quarantine.md)检查来源和签名。

### Git 身份

Git 默认使用主机声明的 `gitName` 和 `email`，无需解密密钥。需要按目录切换身份时，在主机声明中设置 `enablePrivateGit = true`。目录规则、身份设置和对应的 SSH 私钥保存在同一份 [SOPS 密文](secrets/git.yaml) 中；只向应当持有该私钥的设备授权解密。

- **准备密钥**：激活前，将已获授权的 age 私钥保存在 `~/.config/sops/age/keys.txt`，权限设为 `0600`。私钥在仓库外备份，并用备份验证密文可解。
- **编辑配置**：在仓库根目录运行 `SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops edit secrets/git.yaml`。`routing` 保存 Git 的 `includeIf` 规则，以相对路径 `profile-01.inc` 引用 `profile_01` 中的身份设置。修改后重新激活。
- **SSH 认证**：`profile_01` 的 `core.sshCommand` 使用 `ssh_key_01` 解密生成的 `~/.config/sops-nix/secrets/git/ssh-key-01`。这把密钥用于访问 SSH 远端，不改变提交签名配置。对应公钥需在 Git 平台保持授权。
- **验证身份**：在匹配和不匹配规则的仓库中分别运行 `git config --show-origin --get user.email`。前者应来自 `profile-01.inc`，后者应保留默认身份。若仓库另设了 `user.email`，它会覆盖上述配置。
- **验证远端**：在匹配规则且 `origin` 使用 SSH 的仓库中，运行 `git config --show-origin --get core.sshCommand` 确认密钥路径，再运行 `git ls-remote origin HEAD` 验证只读访问。

## 新增主机

1. 以 [homelab](hosts/oevery-homelab.nix) 或 [Mac](hosts/oevery-mac.nix) 为范本，在 `hosts/` 用 `mkHost` 声明主机。选择匹配会话的 `pinentryPackage`：无图形会话用 `pinentry-curses`，GNOME 用 `pinentry-gnome3`，macOS 用 `pinentry_mac`。
2. 在 [主机注册表](hosts/default.nix) 注册。`homeConfigurationName` 必须唯一；Mac 还需要唯一的 `darwinName`。`modules` 只接受[模块注册表](lib/default.nix)中的键。
3. 将新主机文件加入 Git 跟踪后，按[验证命令](docs/commands-cheatsheet.md#core)先做全平台求值，再在目标平台构建。主机与模块的分工见[项目设计](.rsp/specs/design.md)。

### 按设备恢复 Git 签名

GPG 签名材料与共享 Git 身份分开保存。设备文件为 `secrets/git-signing/<设备>.yaml`：设备名取 `homeConfigurationName` 去掉 `<username>-` 前缀，例如 `oevery-mac` 对应 `mac.yaml`。新设备先在 [SOPS 规则](.sops.yaml) 中为自己的文件单独指定接收者，不要沿用共享凭据的授权范围。只有密文加入 Git 跟踪后，Git flake 才能发现它。

- `gpg.default`：个人签名钥的 ASCII-armored 私钥导出包，已包含公钥。激活时自动导入用户的 GnuPG 密钥环，以完整指纹启用签名，不需要另填 `gpgKey`。没有设备文件或省略此字段时，普通提交和标签默认不签名。
- `gpg.profile_01`：可选的独立工作签名钥，不能复用个人钥。省略时工作身份显式关闭签名并清空 `signingKey`；普通提交不签名，仅加 `-S` 也不会误用个人钥。SSH 远端认证不受影响。
- 激活只为有钥匙的身份生成签名覆盖文件。撤掉某个字段或整个设备密文后，下次激活会清理对应的覆盖文件，回到该身份默认不签名的设置，不会删除或撤销密钥环中的钥匙。
- 恢复前先备好设备的 age 私钥及原 GPG 口令。激活时从密文直接导入，不在仓库或 Nix store 写入私钥明文；已配置的密文解不开或钥匙不可用时会报错。

激活后可在个人和工作仓库分别运行 `git config --get --bool commit.gpgSign` 和 `git config --get user.signingKey`。签名提交可用 `git verify-commit HEAD` 验证；它与 SSH 远端读取是两项独立检查。
