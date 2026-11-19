import re
import subprocess

from errors import ControlError


class Backend:
    def __init__(self, settings):
        self.label = settings["serviceName"]
        self.target = f"system/{self.label}"
        self.plist = f"/Library/LaunchDaemons/{self.label}.plist"

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
        match = re.search(r"^\s*pid = (\d+)$", self.info() or "", re.M)
        return int(match[1]) if match else None

    def disabled(self):
        result = self.run("print-disabled", "system", capture=True)
        result.check_returncode()
        return bool(re.search(rf'"{re.escape(self.label)}"\s*=>\s*disabled\b', result.stdout))

    def status(self):
        print(f"开机启动：{'已禁用' if self.disabled() else '已启用'}")
        print(self.info() or "服务状态：未加载", end="\n")

    def start(self):
        if self.info() is None:
            if self.disabled():
                raise ControlError("服务已禁用，请先运行 `mihomoctl enable`。")
            self.run("bootstrap", "system", self.plist)
        elif self.pid() is None:
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
        self.run("enable", self.target)

    def disable(self):
        self.run("disable", self.target)
