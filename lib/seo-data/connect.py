#!/usr/bin/env python3
"""One-time OAuth consent + GSC property discovery + persist. Third-party imports
are lazy so `persist` is testable stdlib-only."""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tokenstore

SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]

def run_consent(client_id, client_secret):
    from google_auth_oauthlib.flow import InstalledAppFlow   # lazy
    cfg = {"installed": {"client_id": client_id, "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": ["http://localhost"]}}
    flow = InstalledAppFlow.from_client_config(cfg, scopes=SCOPES)
    creds = flow.run_local_server(port=0)     # opens browser, one-time consent
    if not creds.refresh_token:
        raise SystemExit("No refresh token returned. Revoke prior grant and retry.")
    return creds.refresh_token

def discover_properties(refresh_token, client_id, client_secret):
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import AuthorizedSession, Request
    creds = Credentials(None, refresh_token=refresh_token, client_id=client_id,
                        client_secret=client_secret,
                        token_uri="https://oauth2.googleapis.com/token", scopes=SCOPES)
    creds.refresh(Request())
    r = AuthorizedSession(creds).get(
        "https://searchconsole.googleapis.com/webmasters/v3/sites", timeout=30)
    r.raise_for_status()
    return [e["siteUrl"] for e in r.json().get("siteEntry", [])]

def persist(store_path, label, refresh_token, scopes, properties):
    tokenstore.save_account(store_path, label, refresh_token, scopes, properties)

def _cli():
    p = argparse.ArgumentParser()
    p.add_argument("--label", required=True)
    p.add_argument("--store", default=os.path.expanduser("~/.claude/seo-data/tokens.json"))
    args = p.parse_args()
    cid = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")
    csec = os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET")
    if not (cid and csec):
        raise SystemExit("Set GOOGLE_OAUTH_CLIENT_ID/SECRET in ~/.claude/.env first.")
    existing = {a["label"] for a in tokenstore.list_accounts(args.store)}
    if args.label in existing:
        ans = input("Label '%s' exists. Overwrite? [y/N] " % args.label).strip().lower()
        if ans != "y":
            raise SystemExit("Aborted.")
    rt = run_consent(cid, csec)
    props = discover_properties(rt, cid, csec)
    persist(args.store, args.label, rt, SCOPES, props)
    print("Connected '%s'. Properties: %s" % (args.label, ", ".join(props) or "(none)"))

if __name__ == "__main__":
    _cli()
