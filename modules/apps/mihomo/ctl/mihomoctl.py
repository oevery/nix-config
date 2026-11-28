import argparse
import fcntl
import json
import os
import re
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import nullcontext
from pathlib import Path

import yaml
import logs
import subscriptions

from backend import Backend
from errors import ControlError
from paths import require_root_owned


APP_DIR = Path(__file__).resolve().parent
SETTINGS = json.loads((APP_DIR / "settings.json").read_text())
STATE = Path(SETTINGS["stateDir"])
CONFIG = Path(SETTINGS["configFile"])
CONTROL = Path(SETTINGS["controlDir"])
LEGACY_SOURCE = CONTROL / "config-source"
REGISTRY = CONTROL / "subscriptions.json"
PLACEHOLDER = Path(SETTINGS["placeholderPath"]) if SETTINGS["placeholderPath"] else None
SERVICE_COMMANDS = {
    "status": "查看配置、运行状态和开机自启状态",
    "start": "启动服务",
    "stop": "停止服务，不改变开机自启设置",
    "restart": "重启服务，未加载时尝试启动",
    "reload": "向运行中的内核发送 SIGHUP；不切换订阅",
    "enable": "开启开机自启，不立即启动服务",
    "disable": "关闭开机自启，不停止服务",
}


def snapshot(service):
    def read(operation):
        try:
            return operation()
        except (PermissionError, OSError, ControlError, subprocess.SubprocessError):
            return None

    def config_state():
        try:
            if not CONFIG.stat().st_size:
                return "placeholder"
        except FileNotFoundError:
            return "missing"
        if PLACEHOLDER is not None:
            try:
                if CONFIG.read_bytes() == PLACEHOLDER.read_bytes():
                    return "placeholder"
            except PermissionError:
                return "private"
        return "installed"

    def selection():
        if not REGISTRY.exists() and LEGACY_SOURCE.exists():
            return True, None
        active = subscriptions.load(REGISTRY)["active_id"]
        return active is not None, active

    def tun_device():
        if CONFIG.stat().st_size > 10485760:
            return None
        try:
            config = yaml.safe_load(CONFIG.read_bytes())
        except (yaml.YAMLError, UnicodeError, RecursionError):
            return None
        tun = config.get("tun") if isinstance(config, dict) else None
        name = tun.get("device") if isinstance(tun, dict) else None
        if isinstance(name, str) and 0 < len(name) <= 32 and name.isascii() and all(
            ch.isalnum() or ch in "_.-" for ch in name
        ):
            return name
        return None

    state, pid = read(service.inspect) or ("unknown", None)
    source_set, active = read(selection) or (None, None)
    return {
        "state": state, "pid": pid, "active_id": active,
        "running": {"running": True, "stopped": False, "failed": False}.get(state),
        "autostart": read(service.autostart_enabled),
        "config": read(config_state), "source_set": source_set,
        "tun_device": read(tun_device), "exit_verified": None,
    }


def probe(interface):
    if interface not in {name for _, name in socket.if_nameindex()}:
        raise ControlError("指定接口不存在，未执行出口验证。")
    if sys.platform == "darwin":
        is_tun = interface.startswith("utun") and interface[4:].isdigit()
    else:
        try:
            is_tun = bool(int((Path("/sys/class/net") / interface / "tun_flags").read_text().strip(), 0) & 1)
        except (OSError, ValueError):
            is_tun = False
    if not is_tun:
        raise ControlError("指定接口不是 TUN，未执行出口验证。")
    result = subprocess.run([
        SETTINGS["curlPath"], "-q", "--noproxy", "*", "--interface", f"if!{interface}",
        "--silent", "--output", os.devnull, "--write-out", "%{http_code}", "--max-time", "8",
        "https://connectivitycheck.gstatic.com/generate_204",
    ], capture_output=True, text=True)
    if result.returncode or result.stdout != "204":
        raise ControlError("指定 TUN 接口未取得预期 HTTPS 204 回执。")
    print(f"{interface} 的 HTTPS 出口已验证；不代表所有目标或规则均可用。")


def download(url, target):
    subscriptions.check_url(url)
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
        raise ControlError(f"下载失败（curl 退出码：{result.returncode}），当前订阅和配置未变更。")


def validate(candidate):
    try:
        config = yaml.safe_load(candidate.read_bytes())
    except (yaml.YAMLError, UnicodeError, RecursionError) as error:
        mark = getattr(error, "problem_mark", None)
        where = f"（第 {mark.line + 1} 行）" if mark else ""
        raise ControlError(f"下载的内容不是有效的 YAML 配置{where}。") from None
    if not isinstance(config, dict) or not isinstance(config.get("rules"), list) or not config["rules"]:
        raise ControlError("请使用包含 `rules` 的完整 Mihomo 配置，而不是节点订阅。")
    result = subprocess.run(
        [SETTINGS["mihomoPath"], "-d", STATE, "-f", candidate, "-t"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=60,
    )
    if result.returncode:
        output = result.stdout.decode(errors="replace").lower()
        category = next((label for marker, label in (
            ("proxy group", "策略组"), ("proxygroup", "策略组"), ("proxy ", "代理节点"),
            ("provider", "provider"), ("rules[", "规则"), ("dns", "DNS"), ("tun.", "TUN"),
        ) if marker in output), "内核配置")
        line = re.search(r"\bline (\d{1,8})\b", output)
        where = f"，第 {line[1]} 行" if line else ""
        raise ControlError(f"Mihomo 校验失败（{category}{where}，退出码 {result.returncode}）；保留原配置。")


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


def effective_content(content):
    return re.sub(rb"\A(#[^\r\n]*\r?\n)# " + "生成时间：".encode() +
                  rb"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\+08:00(\r?\n)", rb"\1\2", content)


def update_config(service, data, selected):
    require_root_owned(STATE, stat.S_ISDIR)
    config_dir = require_root_owned(CONFIG.parent, stat.S_ISDIR)
    require_root_owned(CONFIG, stat.S_ISREG)
    selection = (subscriptions.staged(REGISTRY, {**data, "active_id": selected["id"]})
                 if data["active_id"] != selected["id"] else nullcontext())
    with tempfile.TemporaryDirectory(prefix=".update-", dir=CONFIG.parent) as directory, selection as pending:
        stage = Path(directory)
        candidate = stage / "config.yaml"
        download(selected["url"], candidate)
        validate(candidate)

        if hasattr(service, "require_managed"):
            service.require_managed(applying=True)
        changed = effective_content(candidate.read_bytes()) != effective_content(CONFIG.read_bytes())
        old_pid = None
        backup = None
        if changed:
            state, old_pid = service.inspect()
            if state not in ("running", "stopped", "failed"):
                raise ControlError(f"当前服务状态不允许应用配置：{state}。")
            backup = stage / "previous.yaml"
            os.link(CONFIG, backup)
            os.chown(candidate, 0, config_dir.st_gid)
            os.chmod(candidate, 0o644)

        restart_started = False
        try:
            if changed:
                os.replace(candidate, CONFIG)
                if old_pid is not None:
                    restart_started = True
                    restart_and_check(service, old_pid)
            if pending is not None:
                os.replace(pending, REGISTRY)
        except (OSError, subprocess.SubprocessError, ControlError, KeyboardInterrupt) as error:
            previous_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
            try:
                if backup is not None and not candidate.exists():
                    os.replace(backup, CONFIG)
                if pending is not None and not pending.exists():
                    subscriptions.save(REGISTRY, data)
                if restart_started:
                    try:
                        restart_and_check(service, service.pid())
                    except (OSError, subprocess.SubprocessError, ControlError):
                        raise ControlError("已恢复旧配置和当前订阅，但服务重启失败；请运行 mihomoctl logs。") from None
            finally:
                signal.signal(signal.SIGINT, previous_handler)
            if isinstance(error, KeyboardInterrupt):
                print("更新已取消，配置和当前订阅未变更。", file=sys.stderr)
                raise
            reason = str(error) if isinstance(error, ControlError) else "请检查服务日志和权限。"
            raise ControlError(f"更新失败，已保留原配置和当前订阅。{reason}") from None
    if restart_started:
        message = "配置已校验并安装，服务已重启。"
    elif changed:
        message = "配置已校验并安装，本次未启动服务。"
    else:
        message = "配置无变化。"
    message += f" 当前订阅：{selected['name']}（#{selected['id']}）。"
    return {"changed": changed, "restarted": restart_started,
            "active_id": selected["id"], "message": message}


def manage(args, service):
    data = subscriptions.load(REGISTRY)
    if args.action == "list":
        rows = [{"id": row["id"], "name": row["name"]} for row in data["subscriptions"]]
        if args.json:
            print(json.dumps({"active_id": data["active_id"], "subscriptions": rows}, ensure_ascii=False))
        elif not rows:
            print("尚无订阅。")
        else:
            for row in rows:
                marker = "*" if row["id"] == data["active_id"] else " "
                print(f"{marker} {row['id']}\t{row['name']}")
        return
    if args.action == "add":
        row = subscriptions.add(data, args.name, sys.stdin.readline().rstrip("\r\n"))
        subscriptions.save(REGISTRY, data)
        print(f"已添加订阅 #{row['id']} {row['name']}，尚未应用。")
        return
    if args.action in ("use", "remove"):
        selected = subscriptions.select(data, name=args.name, identifier=args.id)
        if args.action == "remove":
            if selected["id"] == data["active_id"]:
                raise ControlError("不能删除当前订阅；请先切换。")
            data["subscriptions"].remove(selected)
            subscriptions.save(REGISTRY, data)
            print(f"已删除订阅 #{selected['id']}。")
            return
    else:
        if data["active_id"] is None:
            raise ControlError("尚未选择当前订阅，请先运行 mihomoctl subscription use。")
        selected = subscriptions.select(data, identifier=data["active_id"])
    result = update_config(service, data, selected)
    print(json.dumps(result, ensure_ascii=False) if args.json else result["message"])


def main():
    parser = argparse.ArgumentParser(prog="mihomoctl", description="管理 Mihomo 服务和配置。")
    parser.add_argument("--non-interactive", action="store_true", help="需要人工授权时立即失败")
    commands = parser.add_subparsers(dest="command", required=True, title="子命令")
    for name, description in SERVICE_COMMANDS.items():
        action = commands.add_parser(name, help=description, description=description)
        if name == "status":
            action.add_argument("--json", action="store_true")
    probe_cmd = commands.add_parser("probe", help="通过指定 TUN 验证 HTTPS 出口")
    probe_cmd.add_argument("interface")
    log = commands.add_parser("logs", help="读取服务历史日志或内核实时日志")
    log.add_argument("-n", type=int, help="最近行数（默认 100）")
    mode = log.add_mutually_exclusive_group()
    mode.add_argument("-f", "--follow", action="store_true", help="跟随服务日志")
    mode.add_argument("--live", action="store_true", help="订阅本地内核日志，不读取历史")
    log.add_argument("--level", choices=["debug", "info", "warning", "error"], help="内核实时日志级别")
    subs = commands.add_parser("subscription", help="管理完整配置订阅").add_subparsers(dest="action", required=True)
    subs.add_parser("list", help="列出订阅，不显示 URL").add_argument("--json", action="store_true")
    add = subs.add_parser("add", help="添加但不应用订阅")
    add.add_argument("name")
    add.add_argument("--stdin", action="store_true", required=True, help="从标准输入读取 HTTPS 地址")
    for name, description in (("use", "应用并切换订阅"), ("remove", "删除非当前订阅")):
        action = subs.add_parser(name, help=description)
        selector = action.add_mutually_exclusive_group(required=True)
        selector.add_argument("name", nargs="?")
        selector.add_argument("--id", type=int)
        if name == "use":
            action.add_argument("--json", action="store_true")
    config = commands.add_parser("config", help="管理配置源和更新")
    config_commands = config.add_subparsers(dest="action", required=True, title="配置子命令")
    update = config_commands.add_parser("update", help="从已保存的配置源下载并应用配置")
    update.add_argument("--json", action="store_true")
    boot_args = sys.argv[1:]
    if hasattr(Backend, "boot_autostart") and boot_args in (
        ["--run-boot-autostart"], ["--skip-boot-autostart"]
    ):
        args = argparse.Namespace(command="boot_autostart", skip=boot_args[0] == "--skip-boot-autostart")
    else:
        args = parser.parse_args()

    service = Backend(SETTINGS)
    if args.command == "status":
        state = snapshot(service)
        if args.json:
            print(json.dumps(state))
        else:
            flags = {True: "是", False: "否", None: "未知"}
            configs = {"installed": "已安装", "private": "存在（受保护）", "missing": "不存在", "placeholder": "占位配置", None: "不可读取"}
            states = {"running": "运行中", "stopped": "已停止", "not-installed": "未安装",
                      "failed": "启动或运行失败", "starting": "启动中", "stopping": "停止中", "unknown": "未知"}
            active = (f"#{state['active_id']}" if state["active_id"] is not None else
                      {True: "待迁移", False: "未选择", None: "未知（可用 subscription list 查询）"}[state["source_set"]])
            print(f"服务：{states[state['state']]}；开机自启：{flags[state['autostart']]}；"
                  f"配置：{configs[state['config']]}；当前订阅：{active}；出口：未验证")
        return
    if args.command == "probe":
        return probe(args.interface)
    if args.command == "logs":
        if args.live and args.n is not None or args.level and not args.live:
            parser.error("-n 仅用于历史日志，--level 仅用于 --live。")
        if args.n is not None and not 0 <= args.n <= 10000:
            parser.error("-n 必须在 0 到 10000 之间。")
        try:
            if args.live:
                return logs.live(CONFIG, args.level or "info")
            return logs.history(SETTINGS, 100 if args.n is None else args.n, args.follow)
        except PermissionError:
            raise ControlError("当前用户无权读取服务日志；未自动提权。") from None
    if os.geteuid() != 0:
        noninteractive = getattr(args, "non_interactive", False) or not sys.stderr.isatty()
        os.execv(
            SETTINGS["sudoPath"],
            ["sudo", *(["-n"] if noninteractive else []), "--", SETTINGS["pythonPath"], "-I", str(APP_DIR), *sys.argv[1:]],
        )

    os.umask(0o077)
    if PLACEHOLDER is not None and not CONTROL.is_dir():
        raise ControlError("Mihomo 尚未通过 nix-darwin 激活。")
    require_root_owned(CONTROL, stat.S_ISDIR)
    if hasattr(service, "require_managed"):
        service.require_managed(applying=args.command == "config" or getattr(args, "action", None) == "use")
    lock_path = CONTROL / ".ctl.lock"
    require_root_owned(lock_path, stat.S_ISREG, missing_ok=True)
    with lock_path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.command == "boot_autostart":
            if args.skip and require_root_owned(LEGACY_SOURCE, stat.S_ISREG, missing_ok=True):
                LEGACY_SOURCE.chmod(0o600)
            return service.boot_autostart(skip=args.skip)
        if args.command not in ("config", "subscription"):
            if args.command == "reload":
                service.reload()
                print("已请求 SIGHUP 重载；请查看日志确认结果。")
                return
            return getattr(service, args.command)()
        for path, mode in ((LEGACY_SOURCE, 0o600), (REGISTRY, 0o600), (CONFIG, 0o644)):
            if require_root_owned(path, stat.S_ISREG, missing_ok=True):
                path.chmod(mode)
        subscriptions.migrate(REGISTRY, LEGACY_SOURCE)
        manage(args, service)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ControlError as error:
        sys.exit(f"mihomoctl: {error}")
    except subprocess.TimeoutExpired:
        sys.exit("mihomoctl: 操作超时，请检查配置或服务状态。")
    except (OSError, subprocess.SubprocessError):
        sys.exit("mihomoctl: 系统操作失败，请检查服务日志和权限。")
    except KeyboardInterrupt:
        sys.exit(130)
