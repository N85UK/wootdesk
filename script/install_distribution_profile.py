#!/usr/bin/env python3
"""Installs a distribution provisioning profile fetched from App Store Connect.

The release archive signs manually. Automatic signing insists on signing the
archive itself with a development identity, re-signing for distribution only at
export, so uploads succeeded while every archive quietly provisioned for
development. An ephemeral CI runner has no development identity to reuse, so
each run minted a fresh certificate until the account hit Apple's cap and all
delivery stopped.

Manual signing needs the profile present on disk. Fetching it through the API
keeps it out of the repository and out of the secret store, and means a renewed
profile is picked up on the next run rather than after a failed release.

Credentials come from ASC_KEY_ID, ASC_ISSUER_ID and either ASC_KEY_PATH or
ASC_KEY_P8 (base64). Falling back to Infisical keeps local runs working with no
environment set up, matching asc_token.py.

    python3 script/install_distribution_profile.py "WootDesk iOS App Store"
"""
import base64
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

PROFILE_DIR = Path.home() / "Library/MobileDevice/Provisioning Profiles"
API = "https://api.appstoreconnect.apple.com/v1/profiles?limit=200"


def b64(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def from_infisical(key: str) -> str:
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

    # No environment credentials, so this is a local run against the secret store.
    return (from_infisical("ASC_KEY_ID"), from_infisical("ASC_ISSUER_ID"),
            base64.b64decode(from_infisical("ASC_KEY_P8")))


def token() -> str:
    key_id, issuer, pem = credentials()
    key = serialization.load_pem_private_key(pem, password=None)
    now = int(time.time())
    signed = (
        b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"},
                       separators=(",", ":")).encode())
        + b"."
        + b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 900,
                          "aud": "appstoreconnect-v1"},
                         separators=(",", ":")).encode())
    )
    r, s = utils.decode_dss_signature(key.sign(signed, ec.ECDSA(hashes.SHA256())))
    return (signed + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: install_distribution_profile.py <profile name>", file=sys.stderr)
        return 2
    wanted = sys.argv[1]

    # curl, not urllib, because this machine's Python does not trust the issuer
    # of the API host's certificate. asc_token.py works around the same thing.
    result = subprocess.run(
        ["curl", "--silent", "--show-error", "--fail", "--max-time", "30",
         "--header", f"Authorization: Bearer {token()}", API],
        capture_output=True, text=True)
    if result.returncode != 0:
        print(f"error: fetching profiles failed. {result.stderr.strip()}",
              file=sys.stderr)
        return 1
    payload = json.loads(result.stdout)

    matches = [p for p in payload.get("data", [])
               if p["attributes"]["name"] == wanted]
    if not matches:
        names = ", ".join(sorted(p["attributes"]["name"]
                                 for p in payload.get("data", []))) or "none"
        print(f"error: no profile named {wanted!r}. Available: {names}",
              file=sys.stderr)
        return 1

    profile = matches[0]
    attributes = profile["attributes"]
    if attributes["profileState"] != "ACTIVE":
        print(f"error: profile {wanted!r} is {attributes['profileState']}, not ACTIVE.",
              file=sys.stderr)
        return 1

    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    destination = PROFILE_DIR / f"{attributes['uuid']}.mobileprovision"
    destination.write_bytes(base64.b64decode(attributes["profileContent"]))
    print(f"   Installed {wanted} ({attributes['uuid']}), "
          f"expires {attributes['expirationDate'][:10]}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
