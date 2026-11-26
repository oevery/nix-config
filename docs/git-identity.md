# Git 身份与设备授权

Git 作者身份、SSH 远端认证和 GPG 提交签名是三件不同的事。先按需要选择配置：

| 需要什么 | 使用什么配置 |
| --- | --- |
| 只设置默认作者 | 主机的 `gitName` 和 `email`，无需密钥 |
| 按仓库目录切换身份，并用指定 SSH 私钥访问远端 | `enablePrivateGit = true`，授权解密 `secrets/git.yaml` |
| 为提交或标签签名 | 单独授权设备签名文件 `secrets/git-signing/<设备>.yaml`，不由 `enablePrivateGit` 开启 |

`sops` 和 `age` 是共享工具；安装它们不会授予解密权限。以下步骤区分两个角色：**目标设备**将要使用密文，**已获授权的设备**能够解密现有密文并更新接收者。它们各自使用自己的 age 私钥，不要求是特定操作系统。

## 授权设备使用私有 Git

### 1. 在目标设备准备 age 身份

以运行 Home Manager 的用户操作。如果尚未激活且缺少命令，在仓库根目录用锁定的工具进入临时 Shell。先将 `home_name` 设为目标设备的 `homeConfigurationName`：

```bash
nix --extra-experimental-features 'nix-command flakes' shell \
  ".#homeConfigurations.${home_name:?请先设置 home_name}.pkgs.age" \
  ".#homeConfigurations.${home_name}.pkgs.sops"
```

已有身份就复用，不要覆盖。以下命令只在密钥文件不存在时生成新身份，最后输出公钥：

```bash
install -d -m 700 ~/.config/sops/age
test -e ~/.config/sops/age/keys.txt || age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

把**公钥**交给已获授权的设备。私钥留在目标设备，另做仓库外备份；不要把 `keys.txt` 发给其他设备或提交到 Git。

### 2. 在已获授权的设备更新接收者

共享 Git 密文包含目录路由、作者配置和 SSH 私钥。确认目标设备应得到**整份密文**的访问权后，在仓库根目录操作：

1. 在 [`.sops.yaml`](../.sops.yaml) 中找到匹配 `secrets/git.yaml` 的规则，追加目标设备公钥，保留原有接收者。不要改动设备签名文件的规则。
2. 按新规则更新已有密文。只编辑规则不会改变已有密文的接收者：

   ```bash
   SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops updatekeys secrets/git.yaml
   ```

3. 将规则和更新后的密文一起同步到目标设备。此过程不需要导出 SSH 私钥明文。

### 3. 在目标设备验证，再激活

在包含新密文的仓库根目录运行：

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops decrypt secrets/git.yaml >/dev/null
```

退出码为零表示该设备可以解密，且命令不会把明文打印到终端。若失败，先检查密钥路径、接收者和密文版本，**不要激活**。成功后再按[首次安装](../README.md#首次安装)应用配置。恢复备份时也应验证它能解密，而不只是确认文件存在。

## 使用与验证

编辑私有 Git 配置时使用 `SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops edit secrets/git.yaml`，修改后重新激活。`routing` 保存 `includeIf` 路由，以相对路径 `profile-01.inc` 引用 `profile_01`；`ssh_key_01` 提供该身份使用的 SSH 私钥。

- **作者身份：** 在匹配和不匹配路由的仓库中分别运行 `git config --show-origin --get user.email`。匹配时应来自 `profile-01.inc`，否则应为默认身份；仓库本地设置可能覆盖两者。
- **远端认证：** 在匹配路由且 `origin` 使用 SSH 的仓库中，运行 `git config --show-origin --get core.sshCommand`，检查它指向 `~/.config/sops-nix/secrets/git/ssh-key-01`。再用 `git ls-remote origin HEAD` 验证只读访问。解密成功不代表 Git 平台已授权对应的 SSH 公钥。

## 按设备恢复 GPG 签名

设备签名文件位于 `secrets/git-signing/<设备>.yaml`。设备名是 `homeConfigurationName` 去掉 `<username>-` 前缀后的部分。为该文件单独配置 SOPS 接收者，不沿用共享 Git 密文的授权范围。

1. 准备设备的 age 身份及原 GPG 口令。设备密文的 `gpg.default` 保存个人签名钥的 ASCII-armored 私钥导出包（含公钥）；可选的 `gpg.profile_01` 保存独立的工作签名钥，不可复用个人钥。只将密文加入 Git 跟踪，确保 flake 能发现它。
2. 激活前按前述解密命令验证**设备签名文件本身**。激活会从密文导入用户 GnuPG 密钥环，并用完整指纹配置签名；无需另填 `gpgKey`，私钥明文不写入仓库或 Nix store。
3. 在个人和工作仓库分别运行 `git config --get --bool commit.gpgSign` 与 `git config --get user.signingKey` 检查选择结果。对已有的签名提交运行 `git verify-commit HEAD`；这与 SSH 远端访问是独立的检查。

没有设备文件或省略 `gpg.default` 时，普通提交和标签默认不签名。省略 `gpg.profile_01` 时，工作身份关闭签名并清空 `signingKey`，显式 `-S` 也不会误用个人钥。移除字段或设备文件后，下次激活会清理相应的签名覆盖配置，**不会删除或撤销已导入密钥环的钥匙**。
