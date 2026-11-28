import stat
import subprocess
from pathlib import Path

from errors import ControlError
from paths import require_root_owned


INSTALLED_UNIT = Path("/etc/systemd/system/mihomo.service")
PINNED_UNIT = Path("/nix/var/nix/gcroots/mihomo-unit/lib/systemd/system/mihomo.service")


class Backend:
    def __init__(self, settings):
        self.unit = settings["serviceName"]
        self.systemctl = settings["systemctlPath"]
        self.validation_unit = Path(settings["validationUnit"])

    def run(self, *args, check=True, capture=False):
        return subprocess.run(
            [self.systemctl, "--system", "--no-pager", *args, "--", self.unit],
            check=check,
            capture_output=capture,
            text=True,
        )

    def inspect(self):
        result = self.run("show", "--property=LoadState,ActiveState,MainPID", capture=True, check=False)
        properties = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        if properties.get("LoadState") == "not-found":
            return "not-installed", None
        if result.returncode or properties.get("LoadState") != "loaded":
            raise ControlError("无法查询 systemd 服务。")
        pid = properties.get("MainPID", "0")
        if properties.get("ActiveState") == "active" and pid.isdecimal() and int(pid) > 0:
            return "running", int(pid)
        return {"inactive": "stopped", "failed": "failed", "activating": "starting",
                "deactivating": "stopping"}.get(properties.get("ActiveState"), "unknown"), None

    def require_managed(self, *, applying):
        result = self.run("show", "--all", "--property=Id,LoadState,FragmentPath,DropInPaths,NeedDaemonReload",
                          capture=True, check=False)
        props = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        required = {"LoadState": "loaded", "Id": self.unit, "FragmentPath": str(INSTALLED_UNIT),
                    "DropInPaths": "", "NeedDaemonReload": "no"}
        if result.returncode or any(props.get(key) != value for key, value in required.items()):
            raise ControlError("未确认模块安装的 systemd unit；请检查 unit 来源、覆盖项及 daemon-reload。")
        require_root_owned(INSTALLED_UNIT, stat.S_ISREG)
        try:
            pinned = PINNED_UNIT.read_bytes()
        except OSError:
            raise ControlError("无法读取管理员固定的 mihomo-unit；拒绝操作同名服务。") from None
        if INSTALLED_UNIT.read_bytes() != pinned:
            raise ControlError("已安装的 unit 与管理员固定的产物不一致，拒绝操作。")
        if applying and self.validation_unit.read_bytes() != pinned:
            raise ControlError("控制器的校验版本与固定 unit 不一致；请使用配套控制器或由管理员升级 unit。")

    def pid(self):
        return self.inspect()[1]

    def autostart_enabled(self):
        state = self.run("is-enabled", check=False, capture=True).stdout.strip()
        if state in ("enabled", "disabled"):
            return state == "enabled"
        raise ControlError("无法确定开机自启状态。")

    def start(self):
        self.run("start")

    def stop(self):
        self.run("stop")

    def restart(self):
        self.run("restart")

    def reload(self):
        self.run("reload")

    def enable(self):
        self.run("enable")

    def disable(self):
        self.run("disable")
