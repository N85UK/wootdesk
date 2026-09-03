#!/usr/bin/env python3
"""Fails loudly when CI has created a development certificate.

The iOS release archive signs manually, so nothing in the pipeline should ever
create one. It used to: automatic signing signed the archive with a development
identity, and a runner with no identity to reuse minted a fresh certificate
every run until the account hit Apple's cap and delivery stopped without
saying so.

Any certificate named "Created via API" therefore means the signing
configuration has regressed. This is a canary, so it reports rather than
blocks, but it must never be silent about the thing it exists to catch. The
version it replaced depended on pyjwt, which was not installed on the runner,
so it skipped every run while appearing to pass.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc_api import APIError, get  # noqa: E402

CI_DISPLAY_NAME = "Created via API"


def main() -> int:
    try:
        payload = get("/v1/certificates?limit=200")
    except APIError as error:
        # A warning, not a skip: a check that cannot run is not a check that passed.
        print(f"::warning::Certificate check could not run. {error}")
        return 0
    except Exception as error:  # noqa: BLE001
        print(f"::warning::Certificate check could not run. {error}")
        return 0

    development = [c for c in payload.get("data", [])
                   if c["attributes"].get("certificateType") == "DEVELOPMENT"]
    created_by_ci = [c for c in development
                     if c["attributes"].get("displayName") == CI_DISPLAY_NAME]

    print(f"Development certificates: {len(development)}, "
          f"of which CI-created: {len(created_by_ci)}")

    if created_by_ci:
        print(f"::warning::{len(created_by_ci)} CI-created development "
              "certificate(s) exist. The iOS archive signs manually, so this "
              "should be zero. Something has put the Release configuration back "
              "on automatic signing, which mints one per run until Apple's cap "
              "stops delivery entirely. Revoke the surplus and check "
              "CODE_SIGN_STYLE for the Release configuration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
