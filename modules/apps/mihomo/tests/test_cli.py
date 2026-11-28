import contextlib
import gzip
import importlib.util
import io
import json
import os
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "ctl"
sys.path.insert(0, str(SOURCE))
import launchd
import systemd
from errors import ControlError


class ControllerTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.config = self.root / "config.yaml"
        self.config.touch()
        self.registry = self.root / "subscriptions.json"
        self.responses = {}
        self.unit = self.root / "mihomo.service"
        self.pinned = self.root / "pinned.service"
        self.expected = self.root / "expected.service"
        for path in (self.unit, self.pinned, self.expected):
            path.write_text("[Service]\nExecStart=/fixture/core\n")
        self.fragment = self.unit
        self.restarts = []
        self.pid = 0
        self.reject_restart = False
        self.calls = []
        settings = {"stateDir": temp.name, "configFile": str(self.config), "controlDir": temp.name,
                    "placeholderPath": None, "serviceName": "mihomo.service", "systemctlPath": "systemctl",
                    "curlPath": "curl", "mihomoPath": "core", "logDir": temp.name,
                    "validationUnit": str(self.expected), "runMarker": str(self.root / "running"),
                    "sudoPath": "/fixture/sudo", "pythonPath": "/fixture/python"}
        (self.root / "settings.json").write_text(json.dumps(settings))
        entry = self.root / "cli.py"
        shutil.copyfile(SOURCE / "mihomoctl.py", entry)
        spec = importlib.util.spec_from_file_location("fixture_cli", entry)
        self.cli = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, backend=systemd):
            spec.loader.exec_module(self.cli)
        self.addCleanup(os.umask, os.umask(0o077))
        self.enterContext(patch.object(os, "geteuid", return_value=0))
        self.enterContext(patch.object(os, "chown"))
        self.enterContext(patch.object(systemd, "INSTALLED_UNIT", self.unit))
        self.enterContext(patch.object(systemd, "PINNED_UNIT", self.pinned))
        for module in (self.cli, self.cli.subscriptions, systemd):
            self.enterContext(patch.object(module, "require_root_owned", self.owned))
        self.enterContext(patch.object(subprocess, "run", self.external))

    def owned(self, path, expected_type, *, missing_ok=False):
        self.assertTrue(path.is_relative_to(self.root))
        if missing_ok and not path.exists():
            return None
        info = path.lstat()
        self.assertTrue(expected_type(info.st_mode))
        return info

    def external(self, args, **options):
        self.calls.append(args)
        if args[0] == "curl":
            _, _, url = shlex.split(options["input"])
            Path(args[args.index("--output") + 1]).write_text(self.responses[url])
        elif args[0] == "core":
            if Path(args[args.index("-f") + 1]).read_text().startswith("broken:"):
                return subprocess.CompletedProcess(args, 1, b"proxy group: private-value")
        elif "show" in args:
            state = "active" if self.pid else "inactive"
            return subprocess.CompletedProcess(args, 0, f"LoadState=loaded\nActiveState={state}\nMainPID={self.pid}\n"
                                              f"Id=mihomo.service\nFragmentPath={self.fragment}\nDropInPaths=\nNeedDaemonReload=no")
        elif "is-enabled" in args:
            return subprocess.CompletedProcess(args, 1, "disabled")
        elif "restart" in args:
            self.restarts.append(self.config.read_bytes())
            if self.reject_restart:
                self.reject_restart = False
                raise subprocess.CalledProcessError(1, args)
            self.pid += 1
        elif "reload" in args:
            if not self.pid:
                raise subprocess.CalledProcessError(1, args)
        elif "stop" in args:
            self.pid = 0
        else:
            self.fail(f"unexpected command: {args[0]}")
        return subprocess.CompletedProcess(args, 0, b"")

    def run_cli(self, *args, stdin=""):
        out = io.StringIO()
        with patch.object(sys, "argv", ["mihomoctl", *args]), patch.object(sys, "stdin", io.StringIO(stdin)):
            with contextlib.redirect_stdout(out):
                self.cli.main()
        return out.getvalue()

    def test_migration_and_monotonic_selection(self):
        legacy = self.root / "config-source"
        legacy.write_text("https://example.invalid/legacy\n")
        self.assertTrue(json.loads(self.run_cli("status", "--json"))["source_set"])
        self.assertTrue(legacy.exists())
        result = json.loads(self.run_cli("subscription", "list", "--json"))
        self.assertEqual(result, {"active_id": 1, "subscriptions": [{"id": 1, "name": "default"}]})
        self.assertFalse(legacy.exists())
        self.assertEqual(stat.S_IMODE(self.registry.stat().st_mode), 0o600)
        self.run_cli("subscription", "add", "备用", "--stdin", stdin="https://example.invalid/b")
        self.run_cli("subscription", "remove", "--id", "2")
        self.run_cli("subscription", "add", "1", "--stdin", stdin="https://example.invalid/c")
        self.assertFalse(any(command[0] == "curl" for command in self.calls))
        with self.assertRaises(ControlError):
            self.run_cli("subscription", "remove", "--id", "1")
        first = "rules: ['MATCH,DIRECT']\n"
        second = "rules: ['MATCH,REJECT']\n"
        self.responses.update({"https://example.invalid/legacy": first, "https://example.invalid/c": second})
        first_update = json.loads(self.run_cli("config", "update", "--json"))
        self.assertFalse(first_update["restarted"])
        self.assertEqual(self.config.read_text(), first)
        self.pid = 30
        selected = json.loads(self.run_cli("subscription", "use", "1", "--json"))
        self.assertEqual(selected["active_id"], 3)
        self.assertEqual(self.restarts, [second.encode()])
        self.assertNotIn("example.invalid", self.run_cli("subscription", "list", "--json"))
        self.assertEqual(self.config.read_text(), second)
        self.responses["https://example.invalid/c"] = "mode: direct\n" + second
        self.run_cli("config", "update")
        self.assertEqual(self.config.read_text(), "mode: direct\n" + second)

    def test_failed_switch_preserves_active_and_runtime_config(self):
        for name in ("old", "new"):
            self.run_cli("subscription", "add", name, "--stdin", stdin=f"https://example.invalid/{name}")
        self.assertIsNone(json.loads(self.registry.read_text())["active_id"])
        self.responses["https://example.invalid/old"] = "rules: ['MATCH,DIRECT']\n"
        self.run_cli("subscription", "use", "--id", "1")
        old = self.config.read_bytes(), json.loads(self.registry.read_text())
        self.responses["https://example.invalid/new"] = "broken: true\nrules: ['MATCH,REJECT']\n"
        with self.assertRaisesRegex(ControlError, "策略组") as failure:
            self.run_cli("subscription", "use", "new")
        self.assertNotIn("private-value", str(failure.exception))
        new = "mode: direct\nrules: ['MATCH,REJECT']\n"
        self.responses["https://example.invalid/new"] = new
        self.pid = 40
        self.reject_restart = True
        with self.assertRaisesRegex(ControlError, "已保留原配置"):
            self.run_cli("subscription", "use", "--id", "2")
        self.assertEqual((self.config.read_bytes(), json.loads(self.registry.read_text())), old)
        self.assertEqual(self.restarts, [new.encode(), old[0]])

    def test_interrupt_after_selection_replace_restores_both_files(self):
        for name in ("first", "second"):
            self.run_cli("subscription", "add", name, "--stdin", stdin=f"https://example.invalid/{name}")
        self.responses.update({"https://example.invalid/first": "rules: ['MATCH,DIRECT']\n",
                               "https://example.invalid/second": "rules: ['MATCH,REJECT']\n"})
        self.run_cli("subscription", "use", "first")
        replace = os.replace

        def interrupted(source, target):
            replace(source, target)
            if target == self.registry and json.loads(target.read_bytes())["active_id"] == 2:
                raise KeyboardInterrupt

        with patch.object(os, "replace", interrupted), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(KeyboardInterrupt):
                self.run_cli("subscription", "use", "second")
        self.assertEqual(self.config.read_text(), self.responses["https://example.invalid/first"])
        self.assertEqual(json.loads(self.run_cli("subscription", "list", "--json"))["active_id"], 1)

    def test_conflicting_migration_does_not_block_stop(self):
        self.run_cli("subscription", "add", "old", "--stdin", stdin="https://example.invalid/old")
        legacy = self.root / "config-source"
        legacy.write_text("https://example.invalid/another")
        self.pid = 40
        self.run_cli("stop")
        self.assertEqual(self.pid, 0)
        with self.assertRaisesRegex(ControlError, "冲突"):
            self.run_cli("subscription", "list")

    def test_darwin_activation_protects_legacy_without_migration(self):
        legacy = self.root / "config-source"
        legacy.write_text("not a usable subscription")
        legacy.chmod(0o644)
        with patch.object(self.cli, "Backend", launchd.Backend):
            self.run_cli("--skip-boot-autostart")
        self.assertEqual(stat.S_IMODE(legacy.stat().st_mode), 0o600)
        self.assertFalse(self.registry.exists())

    def test_stop_refuses_foreign_or_unpinned_unit(self):
        self.pid = 40
        self.fragment = self.root / "vendor.service"
        with self.assertRaises(ControlError):
            self.run_cli("stop")
        self.fragment = self.unit
        self.unit.write_text("[Service]\nExecStart=/vendor/core\n")
        with self.assertRaises(ControlError):
            self.run_cli("stop")
        self.pinned.unlink()
        with self.assertRaises(ControlError):
            self.run_cli("stop")
        self.assertEqual(self.pid, 40)

    def test_controller_upgrade_cannot_apply_to_different_unit(self):
        self.run_cli("subscription", "add", "daily", "--stdin", stdin="https://example.invalid/daily")
        self.responses["https://example.invalid/daily"] = "rules: ['MATCH,DIRECT']\n"
        self.expected.write_text("[Service]\nExecStart=/fixture/new-core\n")
        with self.assertRaises(ControlError):
            self.run_cli("subscription", "use", "daily")
        self.assertEqual(self.config.read_bytes(), b"")
        self.assertIsNone(json.loads(self.registry.read_text())["active_id"])

    def test_generation_timestamp_does_not_restart(self):
        (self.root / "config-source").write_text("https://example.invalid/test")
        url = "https://example.invalid/test"
        self.responses[url] = "# generated\n# 生成时间：2026-11-28T08:00:00+08:00\nrules: ['MATCH,DIRECT']\n"
        self.run_cli("config", "update")
        self.pid = 30
        self.responses[url] = self.responses[url].replace("T08:", "T09:")
        result = json.loads(self.run_cli("config", "update", "--json"))
        self.assertFalse(result["changed"])
        self.assertFalse(result["restarted"])
        self.assertEqual(self.pid, 30)

    def test_darwin_log_limit_spans_current_file_and_archive(self):
        (self.root / "mihomo.log").write_text("current\n")
        with gzip.open(self.root / "mihomo.log.1.gz", "wb") as stream:
            stream.write(b"older\nprevious\n")
        with patch.object(sys, "platform", "darwin"):
            result = self.run_cli("logs", "-n", "2")
        self.assertEqual(result.splitlines(), ["previous", "current"])

    def test_reload_requires_sudo_and_does_not_apply_subscriptions(self):
        with patch.object(os, "geteuid", return_value=501), patch.object(os, "execv", side_effect=PermissionError) as sudo:
            with self.assertRaises(PermissionError):
                self.run_cli("--non-interactive", "reload")
        binary, args = sudo.call_args.args
        self.assertEqual((binary, args[:3], args[-1]), ("/fixture/sudo", ["sudo", "-n", "--"], "reload"))
        self.pid = 40
        result = self.run_cli("reload")
        self.assertIn("SIGHUP", result)
        self.assertTrue(any("reload" in command for command in self.calls))
        self.assertFalse(self.registry.exists())

    def test_live_logs_use_authenticated_local_stream(self):
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append((self.path, self.headers.get("Authorization")))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"type":"warning","payload":"fixture message"}\n')

            def log_message(self, *args):
                pass

        with HTTPServer(("127.0.0.1", 0), Handler) as server:
            server.timeout = 2
            self.config.write_text(f"external-controller: 127.0.0.1:{server.server_port}\nsecret: fixture\n")
            worker = threading.Thread(target=server.handle_request, daemon=True)
            worker.start()
            out = io.StringIO()
            with contextlib.redirect_stdout(out), patch.object(sys, "argv", ["mihomoctl", "logs", "--live", "--level", "warning"]):
                with self.assertRaisesRegex(ControlError, "已断开"):
                    self.cli.main()
            worker.join(3)
        self.assertEqual(requests, [("/logs?level=warning", "Bearer fixture")])
        self.assertEqual(out.getvalue(), "[warning] fixture message\n")

    def test_status_distinguishes_uninstalled_failed_and_unknown(self):
        for properties, expected in (
            ("LoadState=not-found", "not-installed"),
            ("LoadState=loaded\nActiveState=failed\nMainPID=0", "failed"),
            ("", "unknown"),
        ):
            with self.subTest(expected=expected), patch.object(subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 0, properties)):
                self.assertEqual(json.loads(self.run_cli("status", "--json"))["state"], expected)
