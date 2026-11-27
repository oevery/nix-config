# Linux 任务执行节点

## 模块职责

需要接收任务的主机分别选择任务服务和执行工具，见[主机示例](../hosts/oevery-homelab.nix)。Home Manager 为目标用户配置工具、用户级服务及任务的 `PATH`；节点登记、模型选择和凭据由该用户自行管理。

任务以运行服务的 Linux 用户身份执行，能访问该用户可读写的文件，因此只应允许可信操作者派发任务。服务默认跟随该用户的 systemd 会话；若要求主机重启后无人登录也能接单，由管理员为该用户启用 linger，模块不修改这一系统设置。

## 当前实现：Multica + OMP

在 `x86_64-linux` 主机同时选择 `apps/multica` 和 `apps/omp`。前者提供 `multica-daemon.service`，接到任务后通过用户 profile 找到后者安装的 `omp`。两者也可单选；无需额外部署 Compose worker，也不要执行 `multica daemon enable` 注册第二个服务。

### 安装与更新

OMP 随 Nix generation 安装；Multica CLI 随 `hms` 安装更新，详见[更新及回滚边界](../modules/apps/multica/README.md)。

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
