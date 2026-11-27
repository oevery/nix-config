# 在 Linux 上运行 Magpie 网关

`apps/magpie` 在 `x86_64-linux` 主机上提供模型 API 和浏览器管理页。服务以当前用户身份运行，默认只接受本机连接。

## 首次启用

1. 在目标主机的 `modules` 列表中加入 `"apps/magpie"`，以运行服务的用户执行 `hms`，然后用 `magpie --version` 确认 CLI 已安装。此时如果还没有配置管理密钥，用户服务会跳过启动，不需要运行 `magpie daemon install`。

2. 创建仅自己可读写的环境文件，用编辑器写入一行 `MAGPIE_WEB_KEY=实际的长随机值`。这是管理页的登录密钥，不是客户端调用模型 API 的密钥。

   ```sh
   env_file="${XDG_CONFIG_HOME:-$HOME/.config}/magpie-service/env"
   (umask 077; mkdir -p "$(dirname "$env_file")" && touch "$env_file")
   chmod 600 "$env_file"
   "${EDITOR:-vi}" "$env_file"
   ```

3. 启动服务并验证网关：

   ```sh
   systemctl --user start magpie.service
   systemctl --user is-active magpie.service
   magpie healthcheck
   ```

   `is-active` 应输出 `active`，`healthcheck` 应成功退出。默认模型 API 基址是 `http://127.0.0.1:63425/v1`。在本机浏览器打开 `http://127.0.0.1:63430`，用刚设置的管理密钥登录。若主机没有桌面，可在客户端执行 `ssh -L 13430:127.0.0.1:63430 <SSH主机名>`（替换占位符），再访问 `http://127.0.0.1:13430`。

## 更新与排障

首次安装使用官方 daily 渠道，校验 SHA-256 并试运行后写入 `~/.local/bin/magpie`。之后每次 `hms` 都会关闭后台更新、设置 daily 渠道并检查更新；更新失败但原 CLI 仍可运行时可继续激活。更新可能重启网关，宜在空闲时执行。回滚 Home Manager generation 不会回滚该二进制或用户数据。

若服务未启动，先看 `systemctl --user status magpie.service`，再确认环境文件存在、`MAGPIE_WEB_KEY` 非空、端口未被占用。服务不将标准输出和错误写入 journal，以免记录含管理密钥的链接。如需改端口，在同一环境文件中设置 `MAGPIE_ADDR`（模型 API）或 `MAGPIE_WEB_ADDR`（管理页）；修改后运行 `systemctl --user restart magpie.service`。

只有需要向其他设备提供模型 API 时，才配置网络监听或反向代理。对外开放前，从实际客户端入口确认无密钥和错误密钥的请求都被拒绝，有效的网关密钥可以调用；不要用本机回环测试代替外部鉴权检查。详见 [Magpie 网络与鉴权参考](https://github.com/yetone/magpie/blob/main/docs/reference.md)。
