import subprocess

from errors import ControlError


class Backend:
    def __init__(self, settings):
        self.unit = settings["serviceName"]
        self.systemctl = settings["systemctlPath"]

    def run(self, *args, check=True, capture=False):
        return subprocess.run(
            [self.systemctl, "--system", "--no-pager", *args, "--", self.unit],
            check=check,
            capture_output=capture,
            text=True,
        )

    def pid(self):
        result = self.run("show", "--property=LoadState,ActiveState,MainPID", capture=True)
        properties = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        if properties.get("LoadState") != "loaded":
            raise ControlError(f"无法加载 systemd 服务：{self.unit}。")
        pid = properties.get("MainPID", "0")
        if properties.get("ActiveState") == "active" and pid.isdecimal() and int(pid) > 0:
            return int(pid)
        return None

    def status(self):
        return self.run("status", check=False).returncode

    def start(self):
        self.run("start")

    def stop(self):
        self.run("stop")

    def restart(self):
        self.run("restart")

    def enable(self):
        self.run("enable")

    def disable(self):
        self.run("disable")
