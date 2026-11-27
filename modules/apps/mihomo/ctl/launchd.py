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

    def run(self, *args, capture=False):
        return subprocess.run(
            ["/bin/launchctl", *args],
            check=not capture,
            capture_output=capture,
            text=True,
        )

    def info(self):
        result = self.run("print", self.target, capture=True)
        return result.stdout if result.returncode == 0 else None

    def pid(self):
        return self.pid_from_info(self.info())

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

    def status(self):
        print(f"开机自启：{'开启' if self.autostart_enabled() else '关闭'}")
        info = self.info()
        pid = self.pid_from_info(info)
        print(f"服务状态：{'运行中' if pid is not None else '未运行'}")
        if info:
            print(info, end="\n")

    def start(self):
        if self.info() is None:
            try:
                self.run("bootstrap", "system", self.plist)
            except subprocess.CalledProcessError:
                if self.info() is None:
                    raise
        if self.pid() is None:
            self.run("kickstart", self.target)

    def stop(self):
        if self.info() is not None:
            self.run("bootout", self.target)

    def restart(self):
        if self.info() is None:
            self.start()
        else:
            self.run("kickstart", "-k", self.target)

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
