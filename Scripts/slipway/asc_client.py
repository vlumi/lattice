"""The App Store Connect API client for the listing and screenshot sync.

The release lane's credentials: Key ID + Issuer ID from the project's
Scripts/.asc-config, the .p8 from
~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8 (as distribute.sh finds it).

Needs: PyJWT + cryptography (asc.sh's venv).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


class ASC:
    def __init__(self):
        # Imported here, so the modules load (and test) without the venv.
        try:
            import jwt  # PyJWT
        except ImportError:
            sys.exit("Missing dependency: pip install pyjwt cryptography")
        key_id, issuer, private_key = self._load_config()
        now = int(time.time())
        self._token = jwt.encode(
            {"iss": issuer, "iat": now, "exp": now + 20 * 60,
             "aud": "appstoreconnect-v1"},
            private_key, algorithm="ES256",
            headers={"kid": key_id, "typ": "JWT"})

    @staticmethod
    def _load_config():
        path = os.path.join("Scripts", ".asc-config")
        if not os.path.exists(path):
            sys.exit(f"{path} missing (copy .asc-config.example, fill in Key/Issuer ID).")
        cfg = {}
        for line in open(path):
            line = line.strip()
            if line.startswith("ASC_") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"').strip("'")
        key_id, issuer = cfg.get("ASC_KEY_ID"), cfg.get("ASC_ISSUER_ID")
        if not (key_id and issuer):
            sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID in Scripts/.asc-config.")
        p8 = os.path.expanduser(
            f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")
        if not os.path.exists(p8):
            sys.exit(f"Private key {p8} not found.")
        return key_id, issuer, open(p8).read()

    def _request(self, method, path, body=None, headers=None, raw=False):
        url = path if path.startswith("http") else API + path
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self._token}")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req) as r:
                payload = r.read()
                return payload if raw else (json.loads(payload) if payload else {})
        except urllib.error.HTTPError as e:
            if e.code == 404 and method == "GET":
                return {"data": None}
            detail = e.read().decode(errors="replace")
            raise RuntimeError(f"{method} {path} → HTTP {e.code}: {detail}") from e

    def get(self, path):
        return self._request("GET", path)

    def get_all(self, path):
        """Follow pagination, returning the concatenated `data` list."""
        items, url = [], path
        while url:
            page = self._request("GET", url)
            items += page.get("data", []) or []
            url = page.get("links", {}).get("next")
        return items

    def post(self, path, body):
        return self._request("POST", path, body=body)

    def patch(self, path, body):
        return self._request("PATCH", path, body=body)

    def delete(self, path):
        return self._request("DELETE", path)
