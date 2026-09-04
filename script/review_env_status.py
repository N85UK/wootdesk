#!/usr/bin/env python3
"""Says whether the App Review environment still needs to be running.

`review.n85.app` exists so an Apple reviewer can sign in to a Chatwoot server
with invented data. It is publicly reachable and runs an older Chatwoot than
production, so it should not be left up indefinitely. It should also not be
stopped too early, and "review completed" is the wrong trigger for that: a
rejection means the environment is needed again for the resubmission.

So the rule is review *passed*, on every platform, not review finished.

    python3 script/review_env_status.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc_api import APIError, get  # noqa: E402

APP_ID = "6806847799"

# States where a reviewer, or a resubmission, may still need the environment.
KEEP = {
    "PREPARE_FOR_SUBMISSION",
    "READY_FOR_REVIEW",
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_CONTRACT",
    "WAITING_FOR_EXPORT_COMPLIANCE",
    "REJECTED",
    "METADATA_REJECTED",
    "DEVELOPER_REJECTED",
    "INVALID_BINARY",
    "DEVELOPER_REMOVED_FROM_SALE",
}

# Review is over and it passed. Nothing further needs the demo server.
DONE = {
    "PENDING_DEVELOPER_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_SALE",
    "REPLACED_WITH_NEW_VERSION",
}

STOP_COMMAND = (
    "ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose stop'"
)


def main() -> int:
    try:
        payload = get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")
    except APIError as error:
        print(f"Could not read the App Store state: {error}", file=sys.stderr)
        print("Leaving the environment alone is the safe default.", file=sys.stderr)
        return 2

    versions = [
        (v["attributes"].get("platform"), v["attributes"].get("versionString"),
         v["attributes"].get("appStoreState"))
        for v in payload.get("data", [])
    ]
    if not versions:
        print("No App Store versions found. Leaving the environment alone.")
        return 2

    print("App Store state:")
    for platform, version, state in versions:
        print(f"  {platform:<8} {version:<6} {state}")

    unknown = [s for _, _, s in versions if s not in KEEP and s not in DONE]
    if unknown:
        print(f"\nUnrecognised state(s): {', '.join(sorted(set(unknown)))}.")
        print("Not deciding on a state this script does not know. Leave it running.")
        return 2

    still_needed = [(p, s) for p, _, s in versions if s in KEEP]
    if still_needed:
        print("\nKEEP RUNNING.")
        for platform, state in still_needed:
            print(f"  {platform} is {state}.")
        print("A rejection needs the environment again for the resubmission,")
        print("so it stays up until every platform has passed review.")
        return 1

    print("\nSAFE TO STOP. Every platform has passed review.")
    print(f"\n  {STOP_COMMAND}\n")
    print("Keep the DNS record and the certificate so it can be restarted")
    print("without re-issuing anything.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
