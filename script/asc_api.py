"""Minimal App Store Connect API client shared by the release scripts.

Requests go through curl rather than urllib because this project's Macs do not
trust the issuer of the API host's certificate under Python's own store, which
asc_token.py works around the same way.

Credentials come from ASC_KEY_ID, ASC_ISSUER_ID and either ASC_KEY_PATH or
ASC_KEY_P8 (base64). With none of those set, the values are read from Infisical
so local runs need no environment set up.
"""
import base64
import json
import os
import subprocess
import time
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

BASE = "https://api.appstoreconnect.apple.com"


class APIError(RuntimeError):
    pass


def _b64(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def _from_infisical(key: str) -> str:
    return subprocess.run(
        ["infisical", "secrets", "get", key, "--env=prod", "--path=/apple",
         "--plain", "--silent"],
        capture_output=True, text=True, check=True).stdout.strip()


def credentials() -> tuple[str, str, bytes]:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    key_p8 = os.environ.get("ASC_KEY_P8")

    if key_id and issuer and (key_path or key_p8):
        pem = Path(key_path).read_bytes() if key_path else base64.b64decode(key_p8)
        return key_id, issuer, pem

    return (_from_infisical("ASC_KEY_ID"), _from_infisical("ASC_ISSUER_ID"),
            base64.b64decode(_from_infisical("ASC_KEY_P8")))


def token() -> str:
    key_id, issuer, pem = credentials()
    key = serialization.load_pem_private_key(pem, password=None)
    now = int(time.time())
    signed = (
        _b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"},
                        separators=(",", ":")).encode())
        + b"."
        + _b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 900,
                          "aud": "appstoreconnect-v1"},
                         separators=(",", ":")).encode())
    )
    r, s = utils.decode_dss_signature(key.sign(signed, ec.ECDSA(hashes.SHA256())))
    return (signed + b"." + _b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def get(path: str) -> dict:
    """GETs an API path such as /v1/certificates?limit=200."""
    result = subprocess.run(
        ["curl", "--silent", "--show-error", "--fail", "--max-time", "30",
         "--header", f"Authorization: Bearer {token()}", f"{BASE}{path}"],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise APIError(f"GET {path} failed. {result.stderr.strip()}")
    return json.loads(result.stdout)
