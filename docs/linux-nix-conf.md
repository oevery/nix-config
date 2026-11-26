# 在 Debian 上管理 Nix daemon

[linux-daemon.conf](../config/nix/linux-daemon.conf) 是 homelab 的系统配置来源，适用于多用户 Nix 和 systemd。管理员把它复制到 `/etc/nix/`，安装器的 `nix.conf` 只负责包含这份副本。不要把系统配置软链到普通用户可写的仓库。`git pull` 和 `hms` 都不会更新副本、申请系统权限或重启服务。

## 配置项说明

| 配置项与取值 | 为什么这样设置 |
| --- | --- |
| `extra-experimental-features = nix-command flakes` | `nix-command` 启用 `nix` 子命令，`flakes` 让这些命令能读取仓库的 `flake.nix`。使用 `extra-` 是为了追加所需功能，而不是覆盖宿主已有的列表。 |
| `auto-optimise-store = true` | Nix 用硬链接让 store 中内容相同的文件只占一份磁盘空间。去重不会删除任何一代环境，与 GC 是两种操作。 |

其余选项沿用宿主设置。没有额外覆盖时，Linux 上的 Nix 2.33 默认启用构建沙箱（`sandbox = true`），获取已有二进制替代品失败时不自动转为源码构建（`fallback = false`）。GC 默认保留仍在使用的产物对应的 `.drv`（`keep-derivations = true`），但不会仅因 `.drv` 仍在就保留它的全部输出（`keep-outputs = false`）。用户 registry 和每周 GC 由 [Linux Home Manager 模块](../modules/linux/core/nix.nix) 管理。

## 首次接入

1. 在仓库根目录检查服务和安装器配置：

   ```bash
   systemctl cat nix-daemon.service
   ls -ld /etc/nix /etc/nix/nix.conf
   ```

   确认服务使用 `/etc/nix/nix.conf`，检查其中已有的 `include` 和同名设置。以下步骤假定主配置是 root 管理的普通文件，且 `/etc/nix/linux-daemon.conf` 尚不存在；如果安装器会重新生成主文件、主文件是软链或已有同名片段，先确认其管理方式，不直接覆盖。选择没有活跃构建的维护时段。

2. 为本次操作创建独立备份目录，记下输出路径。先备份原主配置，成功后再安装副本：

   ```bash
   backup=$(sudo mktemp -d /etc/nix/backup.XXXXXXXX) &&
     printf '备份目录：%s\n' "$backup" &&
     sudo cp -a /etc/nix/nix.conf "$backup/nix.conf" &&
     sudo install -o root -g root -m 0644 config/nix/linux-daemon.conf /etc/nix/linux-daemon.conf
   ```

3. 用 `sudoedit /etc/nix/nix.conf` 在末尾加入以下一行，保留原内容，不重复添加。先安装副本再添加引用；不使用 `!include` 静默忽略文件缺失。

   ```text
   include /etc/nix/linux-daemon.conf
   ```

4. 执行下方的[验证与重载](#验证与重载)。备份至少保留到验证完成。

## 后续更新

在仓库根目录运行 `diff -u /etc/nix/linux-daemon.conf config/nix/linux-daemon.conf`。无差异不操作；退出码 `1` 表示两份文件不同，其他非零状态先排查读取错误。确认变更后，备份**当前系统副本**再安装新版本，不改主文件或重复添加 `include`：

```bash
backup=$(sudo mktemp -d /etc/nix/backup.XXXXXXXX) &&
  printf '备份目录：%s\n' "$backup" &&
  sudo cp -a /etc/nix/linux-daemon.conf "$backup/linux-daemon.conf" &&
  sudo install -o root -g root -m 0644 config/nix/linux-daemon.conf /etc/nix/linux-daemon.conf
```

## 验证与重载

先检查副本一致，并忽略个人配置和 `NIX_CONFIG` 检查系统配置解析结果。命令出现未知选项、缺失文件或其他配置警告时不要继续；即使退出码为零也应处理警告。

```bash
cmp config/nix/linux-daemon.conf /etc/nix/linux-daemon.conf
env -u NIX_CONFIG NIX_CONF_DIR=/etc/nix NIX_USER_CONF_FILES=/dev/null nix config show experimental-features
for key in auto-optimise-store sandbox fallback keep-derivations keep-outputs; do
  printf '%s: ' "$key"
  env -u NIX_CONFIG NIX_CONF_DIR=/etc/nix NIX_USER_CONF_FILES=/dev/null nix config show "$key" || break
done
```

`cmp` 应无输出，功能列表应包含 `nix-command` 和 `flakes`。循环的预期值依次为 `true`、`true`、`false`、`true`、`false`。若不同，先检查主配置及其 `include`：例如其他文件仍写着 `keep-outputs = true` 时，精简后的片段不会把它改回 `false`。这些只是新启动的客户端读取结果，不能证明旧 daemon 已加载。确认后重启，再以普通用户测试连接：

```bash
sudo systemctl restart nix-daemon.service &&
  systemctl is-active nix-daemon.service &&
  nix store info --store daemon
```

预期服务为 `active`，最后一条成功连接 daemon。这不是构建或缓存可用性测试。失败时查看 `sudo journalctl -u nix-daemon.service -n 50 --no-pager`；不要通过放宽 `trusted-users` 绕过问题。

## 回滚

使用**对应操作**记录的备份目录；若另开终端，先把 `backup` 设为该目录的实际路径。不要用仓库当前版本代替备份。

- **撤销首次接入：** 若主文件之后未被其他工具修改，执行 `sudo cp -a "${backup:?}/nix.conf" /etc/nix/nix.conf`。若有其他修改，用 `sudoedit` 仅移除本次添加的 `include`。确认没有其他引用后，再将 `/etc/nix/linux-daemon.conf` 移入备份目录留存。
- **撤销一次更新：** 执行 `sudo cp -a "${backup:?}/linux-daemon.conf" /etc/nix/linux-daemon.conf`；主文件中的 `include` 保持不变。

确认恢复后的文件能解析，然后重启服务、检查 `is-active` 和 daemon 连接。若原配置未启用 `nix-command`，用 `nix --extra-experimental-features nix-command store info --store daemon` 检查连接即可，无需为验证重新启用 homelab 配置。
