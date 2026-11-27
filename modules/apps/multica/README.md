# Multica runner

在主机的 `modules` 中选择 `apps/multica`，Home Manager 会管理 Multica CLI 和用户服务，不安装执行引擎。搭配 OMP 的配置、PAT 登记和接单验收见 [Linux 任务执行节点](../../../docs/agent-runner.md)。Mac 的 Multica Desktop cask 不由此模块管理。

首次运行 `hms` 时，从官方 GitHub 最新正式 release 下载 Linux amd64 CLI，核对发布资产的 SHA256 并试运行 `--version` 后才安装到 `~/.local/bin/multica`。首次失败会中止激活。之后每次激活调用该文件的 `multica update`；检查或下载失败但旧 CLI 仍可运行时，会提示并继续激活。`hc`、构建和 dry-run 不会安装或更新 CLI。

systemd 使用 `--no-auto-update` 启动 daemon，只禁用定时自更新。runtime 所有者或工作区管理员仍可在 Multica 网页上手动更新。

只更新 CLI 时，安装脚本不会主动重启 runner；如果用户服务定义也有变化，`hms` 激活时可能重启服务，应等当前任务结束后再切换。保留 `~/.multica`，无需重新登录或登记；回滚 Home Manager generation 不会回滚 `~/.local/bin/multica`。
