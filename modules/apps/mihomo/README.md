# 用 mihomoctl 管理 Mihomo

两端均运行支持 TUN 的系统服务；是否创建 TUN 和修改路由取决于现用配置。macOS 首次激活安装 root LaunchDaemon `org.nixos.mihomo` 和占位配置，不启动代理。Linux 只分发控制器和系统 unit `mihomo.service`，由管理员单独安装。`status`、`logs` 和 `probe` 不自动提权；服务管理、配置更新和私有订阅表访问使用 `sudo`，不会回退到用户态服务。脚本可用 `mihomoctl --non-interactive …` 禁止交互授权。

## 首次使用与订阅

1. 准备可信的 HTTPS **完整 Mihomo 配置**（含 `rules`），不是纯节点或 proxy-provider 订阅。把凭据管理器的输出通过管道交给 `mihomoctl subscription add 日常 --stdin`，不要把私密地址写进命令行。添加只登记，不下载、不切换。
2. `mihomoctl subscription list` 查看名称和 ID，`*` 表示当前项。`mihomoctl subscription use 日常` 或 `mihomoctl subscription use --id 1` 下载、校验并安装；成功才切换当前项。服务原本停止，应用后仍保持停止。
3. 检查监听端口、TUN、虚拟 IP 是否与 Clash Verge 或独立 EasyTier 冲突，再执行 `mihomoctl start`。用 `mihomoctl status` 查看服务，必要时用 `mihomoctl probe <TUN设备>` 验证该接口的一次 HTTPS 出口。

`mihomoctl config update` 刷新当前订阅。名称唯一；裸参数始终按名称解释，包括纯数字名称。`subscription remove 日常` 或 `subscription remove --id 1` 只允许删除非当前项；ID 递增，删除后不复用。`subscription list`、`subscription use` 和 `config update` 支持 `--json`，不输出订阅地址。

`subscriptions.json` 归 root、权限 `0600`，含 `next_id`、`active_id` 和 `{id,name,url}` 列表。首次运行 `subscription` 子命令或 `config update` 时，旧 `config-source` 会导入为当前订阅 `default`，成功后才删除旧文件；迁移本身不下载、不重启、不改现用配置。两份记录冲突时会保留两者并报错。查看状态、启停服务和开机自启均不依赖订阅迁移。macOS 激活时仅将遗留的订阅地址文件收紧到 `0600`，不读取地址。

## 服务与日志

| 命令 | 语义 |
| --- | --- |
| `mihomoctl status [--json]` | 分开显示服务状态、配置和开机自启；无权限或无法判断时报告未知，不视作已停止。JSON 中受保护的订阅信息可能为 `null`。 |
| `mihomoctl start` / `stop` / `restart` | 操作当前服务，不改变开机自启。 |
| `mihomoctl reload` | 向正在运行的内核请求 `SIGHUP` 重载，不启动已停止的服务，也不下载或切换订阅。信号送达不等于配置已成功加载。 |
| `mihomoctl enable` / `disable` | 只修改开机自启。显式 `stop` 后不会被自动恢复；不改变下次开机设置。 |
| `mihomoctl logs -n 50` | 历史服务日志，内核停止后仍可查看已保留记录。 |
| `mihomoctl logs -f` | 显示最近记录后跟随，`Ctrl-C` 退出。 |
| `mihomoctl logs --live --level info` | 通过本机 controller 订阅 Clash 内核实时日志，无历史记录；可选 `debug/info/warning/error`。支持本地 Unix socket 或回环 HTTP，不向远端发送认证信息。连接失败可改查普通 `logs`。 |

Linux 的 stdout、stderr 均进入该 unit 的 journal，保留期和权限由系统管理。macOS 两路输出及自启辅助进程的错误写入 `/Library/Logs/Mihomo/mihomo.log`；新建文件允许本机 `admin` 组读取。每小时检查，达到 `10 MiB` 时 `copytruncate`，压缩保留 5 份，轮转时可能漏少量行。`logs -n` 按合并后的总行数读取，旧分流日志不会被拼接或删除。日志可能包含敏感信息；没有读取权限时由管理员决定是否提权。

Linux 由 systemd 监督内核，退出后间隔 5 秒重启，受 systemd 启动限速约束。服务以 root 运行，capabilities 限于 TUN/路由、原始套接字和低端口绑定。macOS 用本次开机的临时运行标记控制 launchd 的自动恢复；手动停止会撤掉标记并卸载任务。运行意图与持久的开机自启设置分离。

## 更新与恢复

更新使用 `mihomo -t` 校验候选文件。无实质变化（包括仅已知 Surgio 文件头生成时间变化）不重启；其他字节差异按变更处理。进程运行时应用变更会重启并检查新 PID 稳定性，**不等于流量已验证**。重启失败或切换期间按 `Ctrl-C` 会尝试恢复原配置与当前订阅，并分别报告服务恢复失败；不保证断电或 `SIGTERM` 下的跨文件事务。校验错误仅显示安全的阶段、类别或行号，不回显可能含凭据的配置片段。

数据位于 macOS `/Library/Application Support/Mihomo/` 或 Linux `/var/lib/mihomo/`。现用 `config.yaml` 沿用 `root:0644`，**本地用户可读取其中的节点凭据**，与私有订阅表是两种权限边界。不要与其他客户端共用可变目录；节点和规则 provider 按源配置各自的 `interval` 刷新。

## Linux 安装

`hms` 不安装、启用或启动系统服务。管理员先检查模块提供的 store 产物及其 `ExecStart`，确认现有 `mihomo.service` 和 `/var/lib/mihomo` 不属于另一套安装；不要覆盖发行版、第三方 unit 或现有数据。

```sh
bundle=$(realpath "${XDG_DATA_HOME:-$HOME/.local/share}/mihomo/system")
cat "$bundle/lib/systemd/system/mihomo.service"
systemctl cat mihomo.service
```

仅适用于全新安装：如果已有 homelab 或发行版服务，先停在此处。模块不接管、迁移或覆盖旧服务；切换方案、停机时间及旧数据保留由管理员另行决定，不并行启动两个 TUN 服务。

确保目标未被占用后，为**已审阅的确切 store 路径**建立独立 GC root，复制 unit（不要链接到用户可写的 profile），再加载：

```sh
sudo nix-store --realise "$bundle" --add-root /nix/var/nix/gcroots/mihomo-unit
sudo install -o root -g root -m 0644 /nix/var/nix/gcroots/mihomo-unit/lib/systemd/system/mihomo.service /etc/systemd/system/mihomo.service
sudo install -d -o root -g root -m 0755 /var/lib/mihomo
# 仅用于全新安装，无配置文件时：
sudo sh -c 'umask 022; set -C; : > /var/lib/mihomo/config.yaml'
sudo systemctl daemon-reload
```

安装完成后按首次使用流程添加并应用配置，再决定是否启动、开启自启。升级时先审阅和固定新产物，再替换 unit、重新加载并决定重启时间。卸载时先停止、禁用，再移除 unit 和相应 GC root；数据目录默认保留。

Linux 管理操作要求 systemd 已加载上述 `/etc` 副本、内容与专用 GC root 中的 unit 一致、没有额外 drop-in，也没有待重新加载的改动。仅更新用户 generation 不会替换系统服务：如果新控制器配套的 unit 与固定版本不同，仍可停止已确认归属的服务，但不能切换或刷新配置。请使用原配套控制器，或先完成管理员升级。手动替换 unit 与日常管理操作不要并发执行。
