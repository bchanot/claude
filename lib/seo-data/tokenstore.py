#!/usr/bin/env python3
"""Label-keyed OAuth refresh-token store. Atomic writes under an fcntl lock.
No third-party deps — must run without the venv (used by the offline test path)."""
import argparse, fcntl, json, os, tempfile
from contextlib import contextmanager
from datetime import datetime, timezone

def load(path):
    if not os.path.exists(path):
        return {"version": 1, "accounts": {}}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def list_accounts(path):
    data = load(path)
    return [
        {"label": lbl, "properties": a.get("properties", []),
         "granted_at": a.get("granted_at")}
        for lbl, a in data.get("accounts", {}).items()
    ]  # refresh_token intentionally omitted (redaction)

def get_refresh_token(path, label):
    return load(path).get("accounts", {}).get(label, {}).get("refresh_token")

@contextmanager
def _locked(path):
    """Exclusive fcntl lock around a store mutation (serializes writers)."""
    lock_path = path + ".lock"
    with open(lock_path, "w") as lock:
        os.chmod(lock_path, 0o600)                 # defense-in-depth (empty flock handle, never holds token)
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield

def _atomic_write(path, data):
    """tmp → fsync → chmod 0600 → atomic rename, in the store's directory."""
    dirpath = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=dirpath, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.flush(); os.fsync(f.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)                     # atomic
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

def save_account(path, label, refresh_token, scopes, properties):
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, mode=0o700, exist_ok=True)
    os.chmod(dirpath, 0o700)                       # re-assert invariant (makedirs no-ops if dir exists)
    with _locked(path):
        data = load(path)
        data.setdefault("version", 1)
        data.setdefault("accounts", {})
        data["accounts"][label] = {
            "refresh_token": refresh_token,
            "scopes": scopes,
            "granted_at": datetime.now(timezone.utc).isoformat(),
            "properties": properties,
        }
        _atomic_write(path, data)

def remove_account(path, label):
    """Drop one label from the store. Returns True if it existed."""
    if not os.path.exists(path):
        return False
    with _locked(path):
        data = load(path)
        existed = data.get("accounts", {}).pop(label, None) is not None
        if existed:
            _atomic_write(path, data)
    return existed

def clear_accounts(path):
    """Empty the store (file and perms kept). Returns removed count."""
    if not os.path.exists(path):
        return 0
    with _locked(path):
        data = load(path)
        count = len(data.get("accounts", {}))
        _atomic_write(path, {"version": 1, "accounts": {}})
    return count

def _cli():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("list"); pl.add_argument("--file", required=True)
    ps = sub.add_parser("set")
    for flag in ("--file", "--label", "--refresh-token"):
        ps.add_argument(flag, required=True)
    ps.add_argument("--scopes", default="")
    ps.add_argument("--properties", default="")
    pr = sub.add_parser("remove")
    for flag in ("--file", "--label"):
        pr.add_argument(flag, required=True)
    pc = sub.add_parser("clear"); pc.add_argument("--file", required=True)
    try:
        args = p.parse_args()
        if args.cmd == "list":
            print(json.dumps({"status": "ok", "accounts": list_accounts(args.file)}))
        elif args.cmd == "remove":
            print(json.dumps({"status": "ok",
                              "removed": remove_account(args.file, args.label)}))
        elif args.cmd == "clear":
            print(json.dumps({"status": "ok",
                              "cleared": clear_accounts(args.file)}))
        else:
            save_account(args.file, args.label, getattr(args, "refresh_token"),
                         [s for s in args.scopes.split(",") if s],
                         [x for x in args.properties.split(",") if x])
            print(json.dumps({"status": "ok"}))
    except SystemExit as e:                       # argparse usage error
        if e.code not in (0, None):
            print(json.dumps({"status": "error", "reason": "bad_usage"}))
        raise                                     # preserve argparse's exit code
    except Exception:                             # e.g. corrupted store JSON
        print(json.dumps({"status": "degraded", "reason": "unexpected_error"}))

if __name__ == "__main__":
    _cli()
