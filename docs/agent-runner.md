# Linux 任务执行节点

## 模块职责

需要接收任务的 Linux 主机可在主机声明的 `modules` 列表中加入 `linux/agent-runner`，见[已启用该模块的主机示例](../hosts/oevery-homelab.nix)。Home Manager 为目标用户安装执行工具，配置用户级服务及任务的 `PATH`；节点登记、模型选择和凭据由该用户自行管理。

任务以运行服务的 Linux 用户身份执行，能访问该用户可读写的文件，因此只应允许可信操作者派发任务。服务默认跟随该用户的 systemd 会话；若要求主机重启后无人登录也能接单，由管理员为该用户启用 linger，模块不修改这一系统设置。

## 当前实现：Multica + OMP

当前实现适用于 `x86_64-linux`。OMP 由 Nix 安装，Multica CLI 由 Home Manager 在激活时维护。`multica-daemon.service` 运行 Multica daemon，接到任务后启动 OMP。无需额外部署 Compose worker，也不要执行 `multica daemon enable` 注册第二个服务。

### 安装与更新

首次运行 `hms`（或直接激活此主机配置）时，从官方 GitHub 最新正式 release 下载 Linux amd64 CLI，核对发布资产的 SHA256 并试运行 `--version` 后才安装到 `~/.local/bin/multica`。首次失败会中止激活。之后每次激活调用该文件的 `multica update`；检查或下载失败但旧 CLI 仍可运行时，会提示并继续激活。`hc`、构建和 dry-run 不会安装或更新 CLI。

systemd 使用 `--no-auto-update` 启动 daemon，只禁用定时自更新。日常更新随 `hms` 执行；runtime 所有者或工作区管理员仍可在 Multica 网页上手动发起更新。

日常 `hms` 更新不会主动重启服务。已有 Nix 版节点应在没有任务时做首次切换，因为服务的启动路径发生变化。保留 `~/.multica`，无需重新登录或登记。CLI 不再属于 Nix generation，回滚 Home Manager 不会回滚 `~/.local/bin/multica`。

### 首次登记

在目标主机上，以运行任务的用户按 [Linux 激活步骤](../README.md#3-验证并激活)应用该主机的配置。新节点没有默认 profile，或退出登录后 profile 中已无 token，用户服务都会跳过启动。以下命令均以同一用户执行。先替换示例地址并自行核对 HTTPS 域名；接口可达不代表站点可信。

```sh
multica --version
omp --version
unset MULTICA_SERVER_URL MULTICA_PROFILE
server_url=https://multica.example.com
(
  config_file=$(mktemp) || exit 1
  trap 'rm -f "$config_file"' EXIT
  http_status=$(curl -q -sS -o "$config_file" -w '%{http_code}' "${server_url%/}/api/config") &&
    [ "$http_status" = 200 ] &&
    jq -es 'length == 1 and (.[0] |
      (.daemon_setup_target == "self_host" or .daemon_setup_target == "cloud") and
      (.allow_signup | type == "boolean"))' "$config_file" >/dev/null
) &&
  systemd-ask-password 'Multica PAT:' | multica --server-url "$server_url" login --token
```

只有 `/api/config` 直接返回 HTTP 200，且响应是符合 Multica 配置结构的单个 JSON 对象，才会提示输入 PAT。没有出现提示时，先检查反向代理是否返回了重定向或 HTML 登录页。`server_version` 是可选字段，不作为登记条件。

登录成功后启动服务，再在 Multica 界面确认新 runtime 在线且识别到 OMP：

```sh
systemctl --user start multica-daemon.service
multica daemon status
```

Multica CLI 将服务地址和凭据保存在 `~/.multica`，不写入 Nix 配置或 systemd 服务文件。`multica workspace switch <slug>` 只改变 CLI 的默认工作区；若节点只能出现在一个工作区，使用只加入该工作区的 Multica 账号。

若执行节点与 Multica 共用主机，且希望绕开外部 Tunnel，可仅调整该主机的域名解析，让原 HTTPS 域名指向本机反向代理（例如 Traefik 的 `443` 端口）。保留 TLS 校验和同源 `/ws`，无需修改其他设备的解析。

### 验收与维护

- **首次接单：** 在同一 Linux 用户下配置 OMP 的模型与凭据（`~/.omp/agent`），再从 Multica 派一张指定该 runtime 的测试卡并确认模型返回结果。节点在线不等于模型可用；MCP 和搜索都不是注册前提。需要 MCP 时，从实际任务验证一次，stdio 命令须对服务的 `PATH` 可见。
- **重启与日志：** 无任务时运行 `systemctl --user restart multica-daemon.service`，确认原 runtime 重新上线。排障用 `journalctl --user -u multica-daemon.service -b` 和 `multica daemon logs`。不要删除 `~/.multica/daemon.id` 后重新登记。
