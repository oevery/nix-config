import argparse
import fcntl
import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import ExitStack
from pathlib import Path
from urllib.parse import urlsplit

import yaml

from backend import Backend
from errors import ControlError


APP_DIR = Path(__file__).resolve().parent
SETTINGS = json.loads((APP_DIR / "settings.json").read_text())
STATE = Path(SETTINGS["stateDir"])
CONFIG = Path(SETTINGS["configFile"])
CONTROL = Path(SETTINGS["controlDir"])
SOURCE = CONTROL / "config-source"
PLACEHOLDER = Path(SETTINGS["placeholderPath"]) if SETTINGS["placeholderPath"] else None
SERVICE_COMMANDS = {
    "status": "查看配置、服务和开机启动状态",
    "start": "启动服务",
    "stop": "停止服务，不改变开机启动设置",
    "restart": "重启服务，未加载时尝试启动",
    "enable": "允许开机启动，不立即启动服务",
    "disable": "禁止后续启动，不停止正在运行的服务",
}


def print_config_status():
    if not CONFIG.exists():
        config_status = "配置文件不存在"
    elif PLACEHOLDER is not None and CONFIG.read_bytes() == PLACEHOLDER.read_bytes():
        config_status = "尚未配置（使用占位配置，TUN 未启用）"
    else:
        config_status = "配置已安装"
    print(f"配置状态：{config_status}", flush=True)


def require_root_owned(path, expected_type, forbidden_mode):
    try:
        info = path.lstat()
    except FileNotFoundError:
        raise ControlError(f"找不到所需路径：{path}。") from None
    if not expected_type(info.st_mode) or info.st_uid != 0 or info.st_mode & forbidden_mode:
        raise ControlError(f"路径类型、属主或权限不符合要求：{path}。")
    return info


def download(url, target):
    try:
        parsed = urlsplit(url)
        valid = parsed.scheme == "https" and parsed.hostname and parsed.username is None
    except ValueError:
        valid = False
    if not valid or any(char in '"\\' or ord(char) <= 32 for char in url):
        raise ControlError("请输入有效的 HTTPS 地址，不要包含用户名、密码或空白字符。")

    result = subprocess.run(
        [
            SETTINGS["curlPath"], "-q", "--silent", "--fail", "--location", "--max-redirs", "5",
            "--proto", "=https", "--proto-redir", "=https", "--max-time", "60",
            "--max-filesize", "10485760", "--output", target, "--config", "-",
        ],
        input=f'url = "{url}"\n',
        text=True,
    )
    if result.returncode:
        raise ControlError(f"下载失败（curl 退出码：{result.returncode}），配置源未变更。")


def validate(candidate):
    try:
        config = yaml.safe_load(candidate.read_bytes())
    except yaml.YAMLError:
        raise ControlError("下载的内容不是有效的 YAML 配置。") from None
    if not isinstance(config, dict) or not isinstance(config.get("rules"), list) or not config["rules"]:
        raise ControlError("请使用包含 `rules` 的完整 Mihomo 配置，而不是节点订阅。")
    result = subprocess.run(
        [SETTINGS["mihomoPath"], "-d", STATE, "-f", candidate, "-t"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=60,
    )
    if result.returncode:
        raise ControlError("配置未通过 Mihomo 校验，现有配置文件未变更。")


def restart_and_check(service, old_pid):
    service.restart()
    deadline = time.monotonic() + 20
    observed_pid = None
    while time.monotonic() < deadline:
        pid = service.pid()
        if pid is None or pid == old_pid:
            observed_pid = None
        elif pid != observed_pid:
            observed_pid = pid
            stable_since = time.monotonic()
        elif time.monotonic() - stable_since >= 2:
            return
        time.sleep(0.25)
    raise ControlError("Mihomo 未能稳定运行。")


def update_config(service, new_source=None):
    require_root_owned(STATE, stat.S_ISDIR, 0o022)
    require_root_owned(CONFIG.parent, stat.S_ISDIR, 0o022)
    original = require_root_owned(CONFIG, stat.S_ISREG, 0o022)
    if new_source is None and not SOURCE.is_file():
        raise ControlError("尚未设置配置源，请先运行 `mihomoctl config set-source`。")
    url = new_source if new_source is not None else SOURCE.read_text().rstrip("\n")
    with ExitStack() as cleanup:
        stage = Path(cleanup.enter_context(tempfile.TemporaryDirectory(prefix=".update-", dir=CONFIG.parent)))
        candidate = stage / "config.yaml"
        download(url, candidate)
        validate(candidate)

        pending_source = None
        source_backup = None
        if new_source is not None:
            source_stage = Path(cleanup.enter_context(tempfile.TemporaryDirectory(prefix=".source-", dir=CONTROL)))
            pending_source = source_stage / "config-source"
            pending_source.write_text(f"{new_source}\n")
            if SOURCE.exists() or SOURCE.is_symlink():
                require_root_owned(SOURCE, stat.S_ISREG, 0o077)
                source_backup = source_stage / "previous-source"
                os.link(SOURCE, source_backup)

        changed = candidate.read_bytes() != CONFIG.read_bytes()
        old_pid = None
        backup = None
        if changed:
            old_pid = service.pid()
            backup = stage / "previous.yaml"
            os.link(CONFIG, backup)
            os.chown(candidate, original.st_uid, original.st_gid)
            os.chmod(candidate, stat.S_IMODE(original.st_mode))

        restart_started = False
        try:
            if changed:
                os.replace(candidate, CONFIG)
                if old_pid is not None:
                    restart_started = True
                    restart_and_check(service, old_pid)
            if pending_source is not None:
                os.replace(pending_source, SOURCE)
        except (OSError, subprocess.SubprocessError, ControlError, KeyboardInterrupt) as error:
            previous_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
            try:
                if backup is not None and not candidate.exists():
                    os.replace(backup, CONFIG)
                if pending_source is not None and not pending_source.exists():
                    if source_backup is not None:
                        os.replace(source_backup, SOURCE)
                    else:
                        SOURCE.unlink(missing_ok=True)
                if restart_started:
                    try:
                        restart_and_check(service, service.pid())
                    except (OSError, subprocess.SubprocessError, ControlError):
                        raise ControlError("已恢复旧配置和配置源，但服务重启失败，请检查服务日志。") from None
            finally:
                signal.signal(signal.SIGINT, previous_handler)
            if isinstance(error, KeyboardInterrupt):
                print("更新已取消，配置和配置源未变更。", file=sys.stderr)
                raise
            reason = str(error) if isinstance(error, ControlError) else "请检查服务日志和权限。"
            raise ControlError(f"更新失败，已保留原配置和配置源。{reason}") from None
    if restart_started:
        print("配置已校验并安装，服务已重启。")
    elif changed:
        print("配置已校验并安装，本次未启动服务。")
    else:
        print("配置无变化。")
    if new_source is not None:
        print("配置源已保存。")


def main():
    parser = argparse.ArgumentParser(prog="mihomoctl", description="管理 Mihomo 服务和配置。")
    commands = parser.add_subparsers(dest="command", required=True, title="子命令")
    for name, description in SERVICE_COMMANDS.items():
        commands.add_parser(name, help=description, description=description)
    config = commands.add_parser("config", help="管理配置源和更新")
    config_commands = config.add_subparsers(dest="action", required=True, title="配置子命令")
    config_commands.add_parser("update", help="从已保存的配置源下载并应用配置")
    set_source = config_commands.add_parser(
        "set-source", help="应用新配置并保存配置源", description="应用成功后才保存新配置源。"
    )
    source = set_source.add_mutually_exclusive_group(required=True)
    source.add_argument("url", metavar="URL", nargs="?", help="完整 Mihomo 配置的 HTTPS 地址")
    source.add_argument("--stdin", action="store_true", help="从标准输入读取配置地址，适合带凭据的地址")
    args = parser.parse_args()

    if os.geteuid() != 0:
        os.execv(
            SETTINGS["sudoPath"],
            ["sudo", "--", SETTINGS["pythonPath"], "-I", str(APP_DIR), *sys.argv[1:]],
        )

    os.umask(0o077)
    if PLACEHOLDER is not None and not CONTROL.is_dir():
        raise ControlError("Mihomo 尚未通过 nix-darwin 激活。")
    service = Backend(SETTINGS)
    if args.command == "status":
        print_config_status()
        return service.status()
    if args.command != "config" and not CONTROL.exists():
        return getattr(service, args.command)()
    require_root_owned(CONTROL, stat.S_ISDIR, 0o077)
    with (CONTROL / ".ctl.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.command != "config":
            return getattr(service, args.command)()
        else:
            url = None
            if args.action == "set-source":
                url = sys.stdin.readline().rstrip("\r\n") if args.stdin else args.url
            update_config(service, url)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ControlError as error:
        sys.exit(f"mihomoctl: {error}")
    except (OSError, subprocess.SubprocessError):
        sys.exit("mihomoctl: 系统操作失败，请检查服务日志和权限。")
    except KeyboardInterrupt:
        sys.exit(130)
