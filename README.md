# nix-config

这是我的个人 Nix/Home Manager 配置仓库，用于统一管理开发环境与终端体验，并支持多主机复用。

## 快速开始

### 1. 安装 Nix

优先使用清华镜像（多用户模式）：

```bash
sh <(curl -L https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon
```

回退官方安装脚本：

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

推荐优先使用 alias：

- Linux：`hms`
- macOS：`drs`
- macOS 调试：`drst`

每次切换前可先做轻量检查：

```bash
hc
```

完整命令速查见 [docs/commands-cheatsheet.md](docs/commands-cheatsheet.md)。

## 配置约定

### Key 约定

- `homeConfigurations` 使用 `user@host` 作为 key。
- `darwinConfigurations` 使用稳定的 `darwinName` 作为 key，不依赖运行时 `hostname`。

当前示例 Darwin 目标为：`oevery-mac`（定义在 `hosts/oevery-mac.nix`）。

### 平台配置优先级

- Linux（非 NixOS）：优先 `/etc/nix/nix.conf`
- macOS（已启用 nix-darwin）：优先 `modules/darwin/core/system.nix` 的 `nix.settings`

Linux `nix.conf` 参考模板见 [docs/linux-nix-conf.md](docs/linux-nix-conf.md)。

### 软件管理策略

- 优先用 Nix/Home Manager 管理 CLI 与开发环境。
- macOS 下用 Homebrew 补充 GUI 或 Nix 不便安装的应用。

## 验证与排障

标准检查：

```bash
nix flake check
```

快速验证输出可求值：

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

### 生成 hosts gpgKey（简短教程）

- 1. 没有 key 时，先原生生成一个（推荐 Ed25519，默认不过期）：

```bash
gpg --quick-generate-key "Your Name <you@example.com>" ed25519 sign 0
```

`0` 表示永不过期；如需设置有效期，可替换为 `1y`、`2y` 等。

- 2. 查看可用的私钥 Key ID（取 `sec` 行后的长 ID）：

```bash
gpg --list-secret-keys --keyid-format LONG --with-colons you@example.com | awk -F: '$1=="sec"{print $5}'
```

- 3. 将输出的 Key ID 写入对应 `hosts/*.nix`：

```nix
gpgKey = "YOUR_KEY_ID";
```

- 4. 如果你已经有 key，可以直接执行第 2 步提取 Key ID，不必重新生成。
