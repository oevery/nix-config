# 在 macOS 管理 Mihomo

适用于启用 `enableMihomo` 的 nix-darwin 主机。首次激活会安装内核、LaunchDaemon 和占位配置，不会自动启动代理。`mihomoctl` 按操作需要调用 `sudo`。

## 首次使用

1. 准备来自可信来源的 HTTPS **完整配置**（含 `rules`），不是单纯的节点订阅。公开地址可用 `mihomoctl config set-source <URL>` 设置；带凭据的地址通过凭据管理器管道传给 `mihomoctl config set-source --stdin`，不要把地址放进命令参数或 Shell 历史。
2. 启动前检查 TUN、监听端口和虚拟 IP 是否冲突。如果在运行 Clash Verge，先退出或关闭冲突的功能。独立 EasyTier 可以继续运行，但不应与 Mihomo 的原生 EasyTier 出站使用同一个虚拟 IP。
3. 运行 `mihomoctl start`，再用 `mihomoctl status` 和实际连接检查结果。配置校验通过或进程存活都不等于流量能正常转发。

## 日常操作

| 命令 | 作用 |
| --- | --- |
| `mihomoctl status` | 分别查看进程和开机自启状态 |
| `mihomoctl config update` | 从已保存的配置源更新 |
| `mihomoctl start` / `mihomoctl stop` | 启动或停止当前进程，不改变自启设置 |
| `mihomoctl restart` | 重启；服务未加载时尝试启动 |
| `mihomoctl enable` / `mihomoctl disable` | 开启或关闭下次开机自启，不立即启动或停止进程 |

自启状态保存在 `/Library/Application Support/Mihomo/autostart`。只有新的开机会话才尝试自启一次；`drs` 重载任务不会触发启动，进程退出后也不会自动重启。

## 更新与排障

更新会先用 `mihomo -t` 校验。若服务已停止，只安装配置；若服务正在运行且配置有变化，才重启并检查新进程是否稳定存活。重启失败或更新中按 `Ctrl-C` 会回滚配置和源地址；`SIGTERM` 不在这项回滚保障内。变更端口、DNS 或 TUN 后，还需验证实际连接。

```bash
tail -F /Library/Logs/Mihomo/{stdout,stderr}.log
```

`org.nixos.mihomo.logrotate` 每小时检查两个日志文件，各达到 `10 MiB` 时轮转，最多保留 5 份。轮转使用 `copytruncate`，不用重启服务，但可能漏掉少量日志。

配置和状态位于 `/Library/Application Support/Mihomo/`。新建目录和文件默认属于 `root:admin`，权限分别为 `0755` 和 `0644`；本机其他用户可以读取配置、订阅地址和日志。已有路径的权限不会自动修正。不要把其他代理客户端的目录软链到这里；规则和节点 provider 仍按各自配置的 `interval` 刷新。
