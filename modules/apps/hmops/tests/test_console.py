import json
import os
import shlex
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


BINARY = Path(os.environ.get("HMOPS_TEST_BIN", Path(__file__).resolve().parents[1] / "target/debug/hmops")).resolve()
CONTROLLER = """#!/bin/sh
case "$*" in
  'status --json') cat "$HOME/status";;
  'logs -n 100 -f')
    exec 3<> "$HOME/release"
    echo $$ >> "$HOME/follows"
    echo record-A
    read -r release <&3 && echo record-B;;
  *) echo "$*" >> "$HOME/unexpected"; exit 2;;
esac
"""


class ConsoleTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.socket = ["tmux", "-S", str(self.root / "tmux"), "-f", "/dev/null"]
        self.addCleanup(subprocess.run, [*self.socket, "kill-server"], stderr=subprocess.DEVNULL)
        config = self.root / "hmops"
        config.mkdir()
        self.manifest = config / "host.json"
        self.set_modules(["mihomo"])
        self.set_status("unknown")
        controller = self.root / "mihomoctl"
        controller.write_text(CONTROLLER)
        controller.chmod(0o700)
        (self.root / "journalctl").symlink_to(controller)
        os.mkfifo(self.root / "release")
        self.follows = self.root / "follows"

    def tearDown(self):
        self.assertFalse((self.root / "unexpected").exists(), "unexpected controller command")

    def set_status(self, state):
        (self.root / "status").write_text(json.dumps({"state": state, "autostart": True}))

    def set_modules(self, modules):
        self.manifest.write_text(json.dumps({
            "name": "fixture", "system": "x86_64-linux", "modules": ["apps/" + name for name in modules]
        }))

    def tmux(self, *args):
        return subprocess.check_output([*self.socket, *args], text=True)

    def start(self, width, height):
        command = ["env", f"HOME={self.root}", f"XDG_CONFIG_HOME={self.root}",
                   f"PATH={self.root}:{os.environ['PATH']}", str(BINARY), "tui", "--motion", "off"]
        self.tmux("new-session", "-d", "-s", "fixture", "-x", str(width), "-y", str(height),
                  "exec " + shlex.join(command))
        self.see("配置状态")

    def keys(self, *keys):
        self.tmux("send-keys", "-t", "fixture", *keys)

    def see(self, *texts):
        deadline = time.monotonic() + 5
        while True:
            frame = self.tmux("capture-pane", "-pt", "fixture")
            if all(text in frame for text in texts):
                return frame
            if time.monotonic() > deadline:
                self.fail(f"missing {texts} in:\n{frame}")
            time.sleep(.03)

    def services(self):
        self.keys("Right", "Right", "Enter")
        self.see("➤ Mihomo")
        self.keys("Enter")
        return self.see("服务 / Mihomo", "需授权查看")

    def search(self, label, expected):
        self.keys("/", label)
        self.see(expected)
        self.keys("Escape")

    def test_controls_in_detail_and_search(self):
        self.start(104, 24)
        self.search("停止服务", "没有匹配的本机操作")
        detail = self.services()
        self.assertNotIn("服务控制", detail)
        self.search("启动服务", "没有匹配的本机操作")
        for state, status, allowed, denied in (
            ("running", "运行中", "停止服务", "启动服务"),
            ("stopped", "已停止", "启动服务", "停止服务"),
        ):
            self.set_status(state)
            self.keys("r")
            self.assertNotIn(denied, self.see(status, allowed))
            self.search(allowed, f"Mihomo · {allowed}")
            self.search(denied, "没有匹配的本机操作")
        self.set_status("unknown")
        self.keys("Escape")
        self.see("➤ Mihomo", "未知")
        self.search("启动服务", "没有匹配的本机操作")

    def test_pause_at_eof_and_follow_lifecycle(self):
        self.set_modules(["mihomo", "multica"])
        self.start(104, 24)
        self.keys("Right", "Right", "Right", "Enter")
        self.see("日志来源", "➤ Mihomo")
        self.keys("Down")
        self.see("➤ Multica")
        self.keys("Up")
        self.see("➤ Mihomo")
        self.assertFalse(self.follows.exists())
        self.keys("Enter")
        self.see("record-A", "跟随中")
        self.keys("Space")
        self.see("已暂停", "record-A")
        with os.fdopen(os.open(self.root / "release", os.O_WRONLY | os.O_NONBLOCK), "w") as stream:
            stream.write("finish\n")
        self.assertNotIn("record-B", self.see("跟随已结束", "record-A"))
        self.keys("Space")
        self.see("跟随已结束", "record-B")
        self.assertEqual(len(self.follows.read_text().splitlines()), 1)
        self.keys("Escape")
        self.see("➤ Mihomo")
        self.keys("Enter")
        self.see("record-A", "跟随中")
        process = int(self.follows.read_text().splitlines()[-1])
        os.kill(process, 0)
        self.keys("Escape")
        self.see("➤ Mihomo")
        with self.assertRaises(ProcessLookupError):
            os.kill(process, 0)

    def test_layout(self):
        for width, height in ((80, 24), (104, 24), (142, 50)):
            with self.subTest(size=(width, height)):
                self.start(width, height)
                self.services()
                self.keys("Down", "Down", "Enter")
                self.see("服务 / Mihomo / 服务日志", "record-A", "Esc 返回")
                self.keys("Escape")
                self.see("➤ 查看日志")
                self.tmux("kill-session", "-t", "fixture")


if __name__ == "__main__":
    unittest.main()
