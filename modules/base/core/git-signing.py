import json
import os
from pathlib import Path
import re
import subprocess
import sys
from tempfile import NamedTemporaryFile


def command(args, data=None):
    result = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise SystemExit(f"Git signing: {args[0]} {args[1]} failed; signing configuration not updated")
    return result.stdout


def import_signer(armor):
    if not isinstance(armor, str) or not armor.startswith("-----BEGIN PGP PRIVATE KEY BLOCK-----"):
        raise SystemExit("Git signing: expected an armored secret key")
    data = armor.encode()
    listing = command(["gpg", "--batch", "--with-colons", "--show-keys"], data)
    records = [line.split(b":") for line in listing.splitlines()]
    primary = [idx for idx, record in enumerate(records) if record[0] in (b"sec", b"pub")]
    if len(primary) != 1 or records[primary[0]][0] != b"sec":
        raise SystemExit("Git signing: expected exactly one secret key per identity")
    fingerprint = next(record[9].decode() for record in records[primary[0] + 1:] if record[0] == b"fpr")
    if not re.fullmatch(r"[0-9A-F]{40}|[0-9A-F]{64}", fingerprint):
        raise SystemExit("Git signing: invalid fingerprint")
    command(["gpg", "--batch", "--import"], data)
    keys = command(["gpg", "--batch", "--with-colons", "--list-secret-keys", fingerprint])
    if not any(
        len(fields) > 14 and fields[0] in (b"sec", b"ssb") and fields[1] not in (b"r", b"e", b"d", b"i")
        and b"s" in fields[11] and fields[14] == b"+"
        for fields in (line.split(b":") for line in keys.splitlines())
    ):
        raise SystemExit("Git signing: no usable local signing key")
    return fingerprint


def main(directory, encrypted=None):
    os.umask(0o077)
    roles = ("default", "profile_01")
    keys = {} if encrypted is None else json.loads(
        command(["sops", "decrypt", "--output-type", "json", encrypted])
    )["gpg"]
    if not isinstance(keys, dict) or keys.keys() - set(roles):
        raise SystemExit("Git signing: unsupported GPG identity")
    signers = {role: import_signer(value) for role, value in keys.items()}
    if len(set(signers.values())) != len(signers):
        raise SystemExit("Git signing: work and default identities must use separate keys")
    directory = Path(directory)
    if signers:
        directory.mkdir(parents=True, exist_ok=True)
    for role in roles:
        path = directory / (role.replace("_", "-") + ".inc")
        if role not in signers:
            path.unlink(missing_ok=True)
            continue
        with NamedTemporaryFile(mode="w", dir=directory, delete=False) as temp:
            temp.write(f'[user]\n\tsigningKey = "{signers[role]}"\n[commit]\n\tgpgSign = true\n[tag]\n\tgpgSign = true\n')
        os.replace(temp.name, path)


if __name__ == "__main__":
    main(*sys.argv[1:])
