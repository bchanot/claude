#!/usr/bin/env python3
"""Label-keyed OAuth refresh-token store. Atomic writes under an fcntl lock.
No third-party deps — must run without the venv (used by the offline test path)."""
import argparse, fcntl, json, os, sys, tempfile
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

def save_account(path, label, refresh_token, scopes, properties):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    lock_path = path + ".lock"
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)          # serialize concurrent connects
        data = load(path)
        data.setdefault("version", 1)
        data.setdefault("accounts", {})
        data["accounts"][label] = {
            "refresh_token": refresh_token,
            "scopes": scopes,
            "granted_at": datetime.now(timezone.utc).isoformat(),
            "properties": properties,
        }
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
                f.flush(); os.fsync(f.fileno())
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)                 # atomic
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

def _cli():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("list"); pl.add_argument("--file", required=True)
    ps = sub.add_parser("set")
    for flag in ("--file", "--label", "--refresh-token"):
        ps.add_argument(flag, required=True)
    ps.add_argument("--scopes", default="")
    ps.add_argument("--properties", default="")
    args = p.parse_args()
    if args.cmd == "list":
        print(json.dumps({"status": "ok", "accounts": list_accounts(args.file)}))
    else:
        save_account(args.file, args.label, getattr(args, "refresh_token"),
                     [s for s in args.scopes.split(",") if s],
                     [x for x in args.properties.split(",") if x])
        print(json.dumps({"status": "ok"}))

if __name__ == "__main__":
    _cli()
