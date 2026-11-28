import gzip
import http.client
import ipaddress
import json
import os
import socket
import sys
from collections import deque
from contextlib import closing
from pathlib import Path
from urllib.parse import urlsplit

import yaml

from errors import ControlError


def history(settings, count, follow):
    if sys.platform != "darwin":
        args = ["journalctl", "--system", "--no-pager", "-o", "short-iso", "-u",
                settings["serviceName"], "-n", str(count)]
        if follow:
            args.append("-f")
        os.execv("/usr/bin/journalctl", args)
    path = Path(settings["logDir"]) / "mihomo.log"
    try:
        with path.open("rb") as stream:
            current = deque(stream, maxlen=count) if count else ()
    except FileNotFoundError:
        raise ControlError("尚无服务日志；请检查服务是否已安装、启动。") from None
    remaining = count - len(current)
    chunks = []
    for index in range(1, 6):
        if not remaining:
            break
        archive = path.with_name(f"{path.name}.{index}.gz")
        try:
            with gzip.open(archive, "rb") as stream:
                lines = deque(stream, maxlen=remaining)
        except FileNotFoundError:
            continue
        remaining -= len(lines)
        chunks.append(lines)
    for chunk in reversed(chunks):
        for line in chunk:
            sys.stdout.write(line.decode(errors="replace"))
    if follow:
        sys.stdout.flush()
        os.execv("/usr/bin/tail", ["tail", "-n", str(count), "-F", path])
    for line in current:
        sys.stdout.write(line.decode(errors="replace"))


def live(config_path, level):
    try:
        config = yaml.safe_load(config_path.read_bytes())
        if not isinstance(config, dict):
            raise ValueError()
        unix_path = config.get("external-controller-unix")
        endpoint = urlsplit("//" + (config.get("external-controller") or ""))
        if unix_path and isinstance(unix_path, str) and os.path.isabs(unix_path):
            connection = http.client.HTTPConnection("localhost")
            connection.sock = socket.socket(socket.AF_UNIX)
            connection.sock.settimeout(5)
            connection.sock.connect(unix_path)
            headers = {}
        else:
            host = endpoint.hostname
            if host in ("", None, "localhost", "0.0.0.0"):
                host = "127.0.0.1"
            if host == "::":
                host = "::1"
            if not endpoint.port or not ipaddress.ip_address(host).is_loopback:
                raise ValueError()
            connection = http.client.HTTPConnection(host, endpoint.port, timeout=5)
            connection.connect()
            secret = config.get("secret") or ""
            if not isinstance(secret, str) or not secret.isascii() or any(not ch.isprintable() for ch in secret):
                raise ValueError()
            headers = {"Authorization": "Bearer " + secret} if secret else {}
        with closing(connection):
            connection.sock.settimeout(None)
            connection.request("GET", f"/logs?level={level}", headers=headers)
            response = connection.getresponse()
            if response.status != 200:
                raise ControlError(f"内核日志接口返回 HTTP {response.status}；历史日志请用 mihomoctl logs。")
            for line in response:
                event = json.loads(line)
                print(f"[{event['type']}] {event['payload']}", flush=True)
            raise ControlError("内核日志流已断开；历史日志请用 mihomoctl logs。")
    except PermissionError:
        raise ControlError("没有读取日志或控制器的权限；未自动提权。") from None
    except (yaml.YAMLError, ValueError, KeyError, TypeError, OSError, http.client.HTTPException):
        raise ControlError("无法读取本地内核日志流；检查 controller 配置和运行状态，或使用 mihomoctl logs。") from None
