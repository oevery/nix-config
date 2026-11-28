import os
import re
import stat
import subprocess
import tempfile
from pathlib import Path
from uuid import UUID

from errors import ControlError
from paths import require_root_owned


class Backend:
    def __init__(self, settings):
        self.label = settings["serviceName"]
        self.target = f"system/{self.label}"
        self.plist = f"/Library/LaunchDaemons/{self.label}.plist"
        self.autostart_file = Path(settings["controlDir"]) / "autostart"
        self.run_marker = Path(settings["runMarker"])

    def run(self, *args, capture=False):
        return subprocess.run(
            ["/bin/launchctl", *args],
            check=not capture,
            capture_output=capture,
            text=True,
        )

    def info(self):
        result = self.run("print", self.target, capture=True)
        if not result.returncode:
            return result.stdout
        if "could not find service" in result.stderr.lower():
            return None
        raise ControlError("无法查询 launchd 服务。")

    def pid(self):
        return self.pid_from_info(self.info())

    def inspect(self):
        info = self.info()
        if info is None:
            return ("stopped" if Path(self.plist).is_file() else "not-installed"), None
        pid = self.pid_from_info(info)
        if pid:
            return "running", pid
        if self.run_marker.exists():
            return "starting", None
        if re.search(r"^\s*last exit code = (?!0\s*$)-?\d+\s*$", info, re.M):
            return "failed", None
        return "stopped", None

    @staticmethod
    def pid_from_info(info):
        match = re.search(r"^\s*pid = (\d+)$", info or "", re.M)
        return int(match[1]) if match else None

    def autostart_enabled(self):
        return require_root_owned(self.autostart_file, stat.S_ISREG, missing_ok=True) is not None

    def boot_session(self):
        result = subprocess.run(
            ["/usr/sbin/sysctl", "-n", "kern.bootsessionuuid"],
            check=True, capture_output=True, text=True, timeout=5,
        )
        return self.parse_boot_session(result.stdout)

    @staticmethod
    def parse_boot_session(value):
        try:
            return UUID(value.strip())
        except ValueError:
            raise ControlError("无法识别开机记录中的会话编号。") from None

    def record_boot(self, session):
        parent = self.autostart_file.parent
        with tempfile.TemporaryDirectory(prefix=".autostart-", dir=parent) as directory:
            staged = Path(directory) / self.autostart_file.name
            staged.write_text(f"{session}\n")
            os.chown(staged, 0, parent.stat().st_gid)
            staged.chmod(0o644)
            staged.replace(self.autostart_file)

    def start(self):
        existing = require_root_owned(self.run_marker, stat.S_ISREG, missing_ok=True)
        if existing is None:
            self.run_marker.touch(mode=0o600, exist_ok=False)
        try:
            if self.info() is None:
                self.run("bootstrap", "system", self.plist)
            if self.pid() is None:
                self.run("kickstart", self.target)
        except (OSError, ControlError, subprocess.SubprocessError, KeyboardInterrupt):
            if existing is None:
                self.run_marker.unlink(missing_ok=True)
            raise

    def stop(self):
        self.run_marker.unlink(missing_ok=True)
        if self.info() is not None:
            self.run("bootout", self.target)

    def restart(self):
        if not self.run_marker.exists() or self.info() is None:
            self.start()
        else:
            self.run("kickstart", "-k", self.target)

    def reload(self):
        self.run("kill", "SIGHUP", self.target)

    def enable(self):
        self.autostart_enabled()
        self.record_boot(self.boot_session())
        print("已开启开机自启；当前服务状态不变。")

    def disable(self):
        if self.autostart_enabled():
            self.autostart_file.unlink()
        print("已关闭开机自启；仍可手动启动。")

    def boot_autostart(self, *, skip):
        if not self.autostart_enabled():
            return
        session = self.boot_session()
        if self.parse_boot_session(self.autostart_file.read_text()) == session:
            return
        self.record_boot(session)
        if not skip:
            self.start()
