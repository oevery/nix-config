from errors import ControlError


def require_root_owned(path, expected_type, *, missing_ok=False):
    try:
        info = path.lstat()
    except FileNotFoundError:
        if missing_ok:
            return None
        raise ControlError(f"找不到所需路径：{path}。") from None
    if not expected_type(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise ControlError(f"路径类型不符，或未由 root 独占写权限：{path}。")
    return info
