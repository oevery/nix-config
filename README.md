# nix-config

个人 Nix / Home Manager 配置仓库，用于统一管理多主机开发环境。

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

Linux（Home Manager）：

```bash
nix run github:nix-community/home-manager -- switch --flake .#$(whoami)@$(hostname)
```

macOS（nix-darwin，需要 sudo）：

```bash
sudo nix run nix-darwin#darwin-rebuild -- switch --flake .#oevery-mac
```

## 日常使用

常用 alias：

- Linux：`hms`
- macOS：`drs`
- macOS 调试：`drst`

切换前可先检查：

```bash
hc
```

完整命令速查见 [docs/commands-cheatsheet.md](docs/commands-cheatsheet.md)。

## 配置约定

### Key 约定

- `homeConfigurations` 使用 `user@host` 作为 key。
- `darwinConfigurations` 使用稳定的 `darwinName` 作为 key，不依赖运行时 `hostname`。

当前示例 Darwin 目标为：`oevery-mac`（定义在 `hosts/oevery-mac.nix`）。

### 平台配置

- Linux（非 NixOS）：优先 `/etc/nix/nix.conf`
- macOS（nix-darwin）：优先 `modules/darwin/core/system.nix` 中的 `nix.settings`

Linux `nix.conf` 参考模板见 [docs/linux-nix-conf.md](docs/linux-nix-conf.md)。

### 软件管理策略

- 优先用 Nix/Home Manager 管理 CLI 与开发环境。
- macOS 下用 Homebrew 补充 GUI 或 Nix 不便安装的应用。

### Git 本地扩展配置

- 默认保留个人 Git 身份。
- Home Manager 会额外生成 `~/.config/git/local.gitconfig` 与 `~/.config/git/work.gitconfig`。
- 主 Git 配置只 include `~/.config/git/local.gitconfig`，再由这个本地文件继续声明默认的 `includeIf` 规则。
- 默认会把 `~/Developer/work/` 下的仓库导向 `~/.config/git/work.gitconfig`，适合填写公司身份。
- 这些文件只在 Git 运行时被 include，不参与 flake import。

## 验证与排障

标准检查：

```bash
nix flake check
```

快速验证输出：

```bash
nix eval --raw path:$PWD#homeConfigurations."$(whoami)@$(hostname)".activationPackage.drvPath
nix eval --raw path:$PWD#darwinConfigurations.oevery-mac.config.system.build.toplevel.drvPath
```

常见问题：

- 找不到 Linux 主机配置：检查 `hosts/default.nix` 是否注册了 `user@host`。
- Darwin 找不到目标：检查对应 `hosts/*.nix` 是否定义唯一 `darwinName` 并已在 `hosts/default.nix` 注册。
- `modules` 字段报错：`hosts/*.nix` 的 `modules` 只能使用仓库允许的模块键。

## 新增主机

1. 在 `hosts/` 新建主机文件，使用 `mkHost` 定义数据。
2. 在 `hosts/default.nix` 注册该主机。
3. 若为 macOS，设置唯一 `darwinName`。
4. 使用 `nix flake check` 或求值命令验证配置。

### 生成 hosts gpgKey

1. 没有 key 时先生成一个：

```bash
gpg --quick-generate-key "Your Name <you@example.com>" ed25519 sign 0
```

`0` 表示不过期。

1. 查看私钥 Key ID：

```bash
gpg --list-secret-keys --keyid-format LONG --with-colons you@example.com | awk -F: '$1=="sec"{print $5}'
```

1. 将输出的 Key ID 写入对应 `hosts/*.nix`：

```nix
gpgKey = "YOUR_KEY_ID";
```

1. 如果已有 key，直接执行第 2 步即可。
