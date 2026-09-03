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

    python3 script/install_distribution_profile.py "WootDesk iOS App Store"
"""
import base64
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc_api import APIError, get  # noqa: E402

PROFILE_DIR = Path.home() / "Library/MobileDevice/Provisioning Profiles"
PROFILES = "/v1/profiles?limit=200"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: install_distribution_profile.py <profile name>", file=sys.stderr)
        return 2
    wanted = sys.argv[1]

    try:
        payload = get(PROFILES)
    except APIError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

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
