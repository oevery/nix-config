import json
import os
import stat
import tempfile
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import urlsplit

from errors import ControlError
from paths import require_root_owned


def check_url(url):
    try:
        parsed = urlsplit(url)
        valid = parsed.scheme == "https" and parsed.hostname and parsed.username is None
    except ValueError:
        valid = False
    if not valid or any(char in '"\\' or char.isspace() or not char.isprintable() for char in url):
        raise ControlError("请输入有效的 HTTPS 地址，不要包含用户名、密码或空白字符。")


def empty():
    return {"next_id": 1, "active_id": None, "subscriptions": []}


def load(path):
    if require_root_owned(path, stat.S_ISREG, missing_ok=True) is None:
        return empty()
    try:
        data = json.loads(path.read_bytes())
        rows = data["subscriptions"]
        ids = {row["id"] for row in rows}
        names = {row["name"] for row in rows}
        active = data["active_id"]
        if not (
            isinstance(rows, list) and len(ids) == len(names) == len(rows)
            and all(type(value) is int and value > 0 for value in ids)
            and type(data["next_id"]) is int and data["next_id"] > max(ids, default=0)
            and (active is None or type(active) is int and active in ids)
            and all(isinstance(name, str) and name.strip() and name.isprintable() for name in names)
        ):
            raise ValueError()
        for row in rows:
            check_url(row["url"])
        return data
    except (ValueError, KeyError, TypeError, AttributeError, UnicodeError, ControlError):
        raise ControlError("订阅表无效，未覆盖现有记录。") from None


@contextmanager
def staged(path, data):
    with tempfile.TemporaryDirectory(dir=path.parent) as directory:
        candidate = Path(directory) / "subscriptions.json"
        with candidate.open("x", encoding="utf-8") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        yield candidate


def save(path, data):
    with staged(path, data) as candidate:
        os.replace(candidate, path)


def add(data, name, url):
    if not name.strip() or name.strip() != name or not name.isprintable():
        raise ControlError("订阅名称不能为空、含控制字符或首尾空白。")
    if any(row["name"] == name for row in data["subscriptions"]):
        raise ControlError("订阅名称已存在。")
    check_url(url)
    row = {"id": data["next_id"], "name": name, "url": url}
    data["subscriptions"].append(row)
    data["next_id"] += 1
    return row


def select(data, *, name=None, identifier=None):
    for row in data["subscriptions"]:
        if row["name"] == name or row["id"] == identifier:
            return row
    raise ControlError("未找到指定订阅。")


def migrate(path, legacy):
    if require_root_owned(legacy, stat.S_ISREG, missing_ok=True) is None:
        return
    url = legacy.read_text().rstrip("\r\n")
    data = load(path)
    if path.exists():
        if not any(row["url"] == url and row["id"] == data["active_id"] for row in data["subscriptions"]):
            raise ControlError("旧配置源与已有订阅表冲突；已保留两者，请管理员核对。")
    else:
        data["active_id"] = add(data, "default", url)["id"]
        save(path, data)
    legacy.unlink()
