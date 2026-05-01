# 自定义 Git 配置（私有 Profiles）

目标：按目录自动切换 Git 身份（name/email/gpgKey/sshKey），并把敏感信息留在本机私有文件，不提交到仓库。

## 1. 私有配置文件位置

请在本机创建并维护：

- `~/.config/home-manager/.private/git-profiles.nix`

该文件已被仓库忽略（`.gitignore` 已包含对应规则）。

## 2. 快速开始

先复制示例：

```bash
mkdir -p ~/.config/home-manager/.private
cp ~/.config/home-manager/.private/git-profiles.example.nix ~/.config/home-manager/.private/git-profiles.nix
```

然后编辑 `~/.config/home-manager/.private/git-profiles.nix`，填写真实值。

## 3. 配置格式

示例：

```nix
[
  {
    name = "work";
    gitdir = "~/Developer/work/";
    userName = "YOUR_WORK_NAME";
    userEmail = "your.name@company.com";
    # gpgKey = "YOUR_WORK_GPG_KEY";
    # gpgSign = true;
    # sshKey = "~/.ssh/id_ed25519_work";
  }
]
```

字段说明：

- `name`：profile 标识，用于生成 `~/.config/git/profiles/<name>.inc`
- `gitdir`：目录匹配规则，建议以 `/` 结尾
- `userName`：该目录下仓库使用的 Git 用户名
- `userEmail`：该目录下仓库使用的 Git 邮箱
- `gpgKey`：可选，设置后会写入 signingKey
- `gpgSign`：可选，不填时默认跟随 `gpgKey`（有 key 则 true）
- `sshKey`：可选，设置后会为该 profile 生成专用 sshCommand

## 4. 生效

修改后执行你日常的切换命令：

- Linux：`hms`
- macOS：`drs`

## 5. 验证

在目标仓库中检查：

```bash
git config --show-origin --get user.name
git config --show-origin --get user.email
git config --show-origin --get commit.gpgsign
```

如果命中了 profile，会看到来源为 `~/.config/git/profiles/<name>.inc`。

## 6. 参考文件

- `docs/git-profiles.private.nix.example`
- `.private/git-profiles.example.nix`
- `modules/base/core/host.nix`
